#!/usr/bin/env python3
"""Attach a Race Book paywall screenshot to the App Store Connect IAP."""

from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE_ID = "com.jackwallner.ironman"
PRODUCT_ID = "com.jackwallner.ironman.pro"
V1 = "https://api.appstoreconnect.apple.com/v1"
V2 = "https://api.appstoreconnect.apple.com/v2"


def upload(client: asc_lib.ASCClient, iap_id: str, image: Path) -> None:
    blob = image.read_bytes()
    old_api = asc_lib.API
    try:
        asc_lib.API = V2
        existing = client.get(f"/inAppPurchases/{iap_id}/appStoreReviewScreenshot").get("data")
        if existing:
            print(f"review screenshot already attached: {existing['id']}")
            return
        reserved = client.post(
            "/inAppPurchaseAppStoreReviewScreenshots",
            {
                "data": {
                    "type": "inAppPurchaseAppStoreReviewScreenshots",
                    "attributes": {"fileSize": len(blob), "fileName": image.name},
                    "relationships": {
                        "inAppPurchaseV2": {
                            "data": {"type": "inAppPurchases", "id": iap_id}
                        }
                    },
                }
            },
        )["data"]
        for operation in reserved["attributes"].get("uploadOperations", []):
            chunk = blob[operation["offset"] : operation["offset"] + operation["length"]]
            request = urllib.request.Request(
                operation["url"], data=chunk, method=operation["method"]
            )
            for header in operation.get("requestHeaders", []):
                request.add_header(header["name"], header["value"])
            with urllib.request.urlopen(request, timeout=300) as response:
                response.read()
        client.request(
            "PATCH",
            f"/inAppPurchaseAppStoreReviewScreenshots/{reserved['id']}",
            {
                "data": {
                    "type": "inAppPurchaseAppStoreReviewScreenshots",
                    "id": reserved["id"],
                    "attributes": {
                        "uploaded": True,
                        "sourceFileChecksum": hashlib.md5(blob).hexdigest(),
                    },
                }
            },
        )
        print(f"attached review screenshot: {reserved['id']}")
    finally:
        asc_lib.API = old_api


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screenshot", required=True, type=Path)
    args = parser.parse_args()
    if not args.screenshot.is_file():
        raise SystemExit(f"error: screenshot does not exist: {args.screenshot}")
    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    old_api = asc_lib.API
    try:
        # The collection endpoint is part of the v1 API. The upload resource
        # itself uses v2 after the product ID has been resolved.
        asc_lib.API = V1
        products = asc_lib.list_all(client, f"/apps/{app['id']}/inAppPurchasesV2")
    finally:
        asc_lib.API = old_api
    iap = next(
        (item for item in products if item["attributes"].get("productId") == PRODUCT_ID),
        None,
    )
    if iap is None:
        raise SystemExit(f"error: App Store Connect product does not exist: {PRODUCT_ID}")
    upload(client, iap["id"], args.screenshot)


if __name__ == "__main__":
    main()
