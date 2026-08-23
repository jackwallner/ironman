#!/usr/bin/env python3
"""Finish the Race Book in-app purchase metadata and review screenshot."""

from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import asc_lib


BUNDLE_ID = "com.jackwallner.ironman"
PRODUCT_ID = "com.jackwallner.ironman.pro"
NAME = "Race Book"
DESCRIPTION = "Compare races and export your race history forever."
V1 = "https://api.appstoreconnect.apple.com/v1"
V2 = "https://api.appstoreconnect.apple.com/v2"
EDITABLE_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"}


def with_api(client: asc_lib.ASCClient, api: str, action):
    previous = asc_lib.API
    try:
        asc_lib.API = api
        return action()
    finally:
        asc_lib.API = previous


def find_product(client: asc_lib.ASCClient, app_id: str) -> dict:
    products = with_api(
        client,
        V1,
        lambda: asc_lib.list_all(client, f"/apps/{app_id}/inAppPurchasesV2"),
    )
    product = next(
        (
            item
            for item in products
            if item.get("attributes", {}).get("productId") == PRODUCT_ID
        ),
        None,
    )
    if product is None:
        raise SystemExit(f"error: App Store Connect product does not exist: {PRODUCT_ID}")
    return product


def ensure_localization(client: asc_lib.ASCClient, product_id: str) -> None:
    versions = with_api(
        client,
        V2,
        lambda: asc_lib.list_all(client, f"/inAppPurchases/{product_id}/versions"),
    )
    version = next(
        (
            item
            for item in versions
            if item.get("attributes", {}).get("state") in EDITABLE_STATES
        ),
        None,
    )
    if version is None:
        version = with_api(
            client,
            V1,
            lambda: client.post(
                "/inAppPurchaseVersions",
                {
                    "data": {
                        "type": "inAppPurchaseVersions",
                        "relationships": {
                            "inAppPurchase": {
                                "data": {"type": "inAppPurchases", "id": product_id}
                            }
                        },
                    }
                },
            ),
        )["data"]
        print(f"created IAP metadata version {version['id']}")
    else:
        print(f"IAP metadata version {version['id']}: {version['attributes'].get('state')}")

    version_id = version["id"]
    localizations = with_api(
        client,
        V1,
        lambda: asc_lib.list_all(
            client, f"/inAppPurchaseVersions/{version_id}/localizations"
        ),
    )
    existing = next(
        (item for item in localizations if item.get("attributes", {}).get("locale") == "en-US"),
        None,
    )
    if existing is None:
        with_api(
            client,
            V2,
            lambda: client.post(
                "/inAppPurchaseLocalizations",
                {
                    "data": {
                        "type": "inAppPurchaseLocalizations",
                        "attributes": {"locale": "en-US", "name": NAME, "description": DESCRIPTION},
                        "relationships": {
                            "version": {
                                "data": {"type": "inAppPurchaseVersions", "id": version_id}
                            }
                        },
                    }
                },
            ),
        )
        print("created en-US IAP localization")
        return

    attributes = existing.get("attributes", {})
    changes = {}
    if attributes.get("name") != NAME:
        changes["name"] = NAME
    if attributes.get("description") != DESCRIPTION:
        changes["description"] = DESCRIPTION
    if changes:
        with_api(
            client,
            V2,
            lambda: client.request(
                "PATCH",
                f"/inAppPurchaseLocalizations/{existing['id']}",
                {
                    "data": {
                        "type": "inAppPurchaseLocalizations",
                        "id": existing["id"],
                        "attributes": changes,
                    }
                },
            ),
        )
        print(f"updated en-US IAP localization: {', '.join(sorted(changes))}")
    else:
        print("en-US IAP localization is complete")


def verify_price_and_availability(client: asc_lib.ASCClient, product_id: str) -> None:
    prices = with_api(
        client,
        V1,
        lambda: client.get(
            f"/inAppPurchasePriceSchedules/{product_id}/manualPrices"
            "?include=inAppPurchasePricePoint&filter[territory]=USA"
        ),
    )
    points = [
        item
        for item in prices.get("included", [])
        if item.get("type") == "inAppPurchasePricePoints"
    ]
    customer_price = points[0].get("attributes", {}).get("customerPrice") if points else "unknown"
    availability = with_api(
        client,
        V2,
        lambda: client.get(f"/inAppPurchases/{product_id}/inAppPurchaseAvailability").get("data"),
    )
    available = bool(availability and availability.get("attributes", {}).get("availableInNewTerritories"))
    print(f"USA price ${customer_price}; available in new territories={available}")


def upload_review_screenshot(client: asc_lib.ASCClient, product_id: str, image: Path) -> None:
    blob = image.read_bytes()
    existing = with_api(
        client,
        V2,
        lambda: client.get(f"/inAppPurchases/{product_id}/appStoreReviewScreenshot").get("data"),
    )
    if existing:
        print(f"IAP review screenshot already exists: {existing['id']}")
        return

    reserved = with_api(
        client,
        V1,
        lambda: client.post(
            "/inAppPurchaseAppStoreReviewScreenshots",
            {
                "data": {
                    "type": "inAppPurchaseAppStoreReviewScreenshots",
                    "attributes": {"fileSize": len(blob), "fileName": image.name},
                    "relationships": {
                        "inAppPurchaseV2": {
                            "data": {"type": "inAppPurchases", "id": product_id}
                        }
                    },
                }
            },
        ),
    )["data"]
    for operation in reserved.get("attributes", {}).get("uploadOperations", []):
        offset = int(operation["offset"])
        length = int(operation["length"])
        request = urllib.request.Request(
            operation["url"],
            data=blob[offset : offset + length],
            method=operation["method"],
        )
        for header in operation.get("requestHeaders", []):
            request.add_header(header["name"], header["value"])
        with urllib.request.urlopen(request, timeout=300) as response:
            response.read()

    checksum = hashlib.md5(blob).hexdigest()
    with_api(
        client,
        V1,
        lambda: client.request(
            "PATCH",
            f"/inAppPurchaseAppStoreReviewScreenshots/{reserved['id']}",
            {
                "data": {
                    "type": "inAppPurchaseAppStoreReviewScreenshots",
                    "id": reserved["id"],
                    "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
                }
            },
        ),
    )
    print(f"attached IAP review screenshot {reserved['id']}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screenshot", required=True, type=Path)
    args = parser.parse_args()
    if not args.screenshot.is_file():
        raise SystemExit(f"error: screenshot does not exist: {args.screenshot}")

    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    product = find_product(client, app["id"])
    product_id = product["id"]
    print(f"product {product_id}: {product['attributes'].get('state')}")
    ensure_localization(client, product_id)
    verify_price_and_availability(client, product_id)
    upload_review_screenshot(client, product_id, args.screenshot)


if __name__ == "__main__":
    main()
