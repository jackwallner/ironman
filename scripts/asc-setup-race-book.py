#!/usr/bin/env python3
"""Create or verify the Race Book lifetime product in App Store Connect."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE_ID = "com.jackwallner.ironman"
PRODUCT_ID = "com.jackwallner.ironman.pro"
REFERENCE_NAME = "Race Book"
DISPLAY_NAME = "Race Book"
DESCRIPTION = "Compare races and export your Race Book."
PRICE = "9.99"
V1 = "https://api.appstoreconnect.apple.com/v1"
V2 = "https://api.appstoreconnect.apple.com/v2"


def product_price(client: asc_lib.ASCClient, product_id: str) -> str | None:
    old_api = asc_lib.API
    try:
        asc_lib.API = V2
        schedule = client.get(f"/inAppPurchases/{product_id}/iapPriceSchedule").get("data")
        if not schedule:
            return None
        schedule_id = schedule["id"]
        asc_lib.API = V1
        manual_prices = client.get(
            f"/inAppPurchasePriceSchedules/{schedule_id}/manualPrices"
            "?include=inAppPurchasePricePoint&filter[territory]=USA"
        )
        point = next(
            (
                item
                for item in manual_prices.get("included", [])
                if item.get("type") == "inAppPurchasePricePoints"
            ),
            None,
        )
        return str(point.get("attributes", {}).get("customerPrice")) if point else None
    except RuntimeError:
        return None
    finally:
        asc_lib.API = old_api


def main() -> None:
    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    app_id = app["id"]
    print(f"app {app_id}: {app['attributes']['name']}")

    iaps = asc_lib.list_all(client, f"/apps/{app_id}/inAppPurchasesV2")
    iap = next((item for item in iaps
                if item["attributes"].get("productId") == PRODUCT_ID), None)
    if iap is None:
        old_api = asc_lib.API
        try:
            asc_lib.API = V2
            iap = client.post(
                "/inAppPurchases",
                {
                    "data": {
                        "type": "inAppPurchases",
                        "attributes": {
                            "name": REFERENCE_NAME,
                            "productId": PRODUCT_ID,
                            "inAppPurchaseType": "NON_CONSUMABLE",
                            "reviewNote": "One-time Race Book purchase. No subscription and no per-export charge.",
                        },
                        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                    }
                },
            )["data"]
        finally:
            asc_lib.API = old_api
        print("created App Store Connect product")
    else:
        print(f"product exists: {iap['id']}")

    iap_id = iap["id"]
    if iap["attributes"].get("name") != REFERENCE_NAME:
        old_api = asc_lib.API
        try:
            asc_lib.API = V2
            client.request(
                "PATCH",
                f"/inAppPurchases/{iap_id}",
                {
                    "data": {
                        "type": "inAppPurchases",
                        "id": iap_id,
                        "attributes": {"name": REFERENCE_NAME},
                    }
                },
            )
        finally:
            asc_lib.API = old_api
        print("updated Apple product name")

    old_api = asc_lib.API
    try:
        asc_lib.API = V2
        versions = asc_lib.list_all(client, f"/inAppPurchases/{iap_id}/versions")
    finally:
        asc_lib.API = old_api
    editable_states = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"}
    version = next(
        (
            item
            for item in versions
            if item.get("attributes", {}).get("state") in editable_states
        ),
        None,
    )
    if version is None:
        version = client.post(
            "/inAppPurchaseVersions",
            {
                "data": {
                    "type": "inAppPurchaseVersions",
                    "relationships": {
                        "inAppPurchase": {
                            "data": {"type": "inAppPurchases", "id": iap_id}
                        }
                    },
                }
            },
        )["data"]
        print("created draft metadata version")
    else:
        print(f"metadata version exists: {version['id']}")

    version_id = version["id"]
    old_api = asc_lib.API
    try:
        asc_lib.API = V1
        localizations = asc_lib.list_all(
            client, f"/inAppPurchaseVersions/{version_id}/localizations"
        )
    finally:
        asc_lib.API = old_api
    existing = next(
        (item for item in localizations if item["attributes"].get("locale") == "en-US"),
        None,
    )
    if existing is None:
        old_api = asc_lib.API
        try:
            asc_lib.API = V2
            client.post(
                "/inAppPurchaseLocalizations",
                {
                    "data": {
                        "type": "inAppPurchaseLocalizations",
                        "attributes": {
                            "locale": "en-US",
                            "name": DISPLAY_NAME,
                            "description": DESCRIPTION,
                        },
                        "relationships": {
                            "version": {
                                "data": {
                                    "type": "inAppPurchaseVersions",
                                    "id": version_id,
                                }
                            }
                        },
                    }
                },
            )
        finally:
            asc_lib.API = old_api
        print("created en-US localization")
    else:
        current_attributes = existing["attributes"]
        if (current_attributes.get("name") != DISPLAY_NAME
                or current_attributes.get("description") != DESCRIPTION):
            old_api = asc_lib.API
            try:
                asc_lib.API = V2
                client.request(
                    "PATCH",
                    f"/inAppPurchaseLocalizations/{existing['id']}",
                    {
                        "data": {
                            "type": "inAppPurchaseLocalizations",
                            "id": existing["id"],
                            "attributes": {
                                "name": DISPLAY_NAME,
                                "description": DESCRIPTION,
                            },
                        }
                    },
                )
            finally:
                asc_lib.API = old_api
            print("updated en-US Apple product metadata")
        else:
            print("en-US localization exists")

    current_price = product_price(client, iap_id)
    if current_price == PRICE:
        print(f"price already ${PRICE}")
    elif current_price is not None:
        raise SystemExit(
            f"error: existing price is ${current_price}; refusing to replace it automatically"
        )
    else:
        old_api = asc_lib.API
        try:
            asc_lib.API = V2
            points = asc_lib.list_all(
                client, f"/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200"
            )
        finally:
            asc_lib.API = old_api
        point = next((item for item in points
                      if str(item["attributes"].get("customerPrice")) == PRICE), None)
        if point is None:
            raise SystemExit(f"error: USA price point ${PRICE} is unavailable")
        client.post(
            "/inAppPurchasePriceSchedules",
            {
                "data": {
                    "type": "inAppPurchasePriceSchedules",
                    "relationships": {
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                        "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                        "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price0}"}]},
                    },
                },
                "included": [
                    {
                        "type": "inAppPurchasePrices",
                        "id": "${price0}",
                        "attributes": {"startDate": None},
                        "relationships": {
                            "inAppPurchasePricePoint": {
                                "data": {
                                    "type": "inAppPurchasePricePoints",
                                    "id": point["id"],
                                }
                            }
                        },
                    }
                ],
            },
        )
        print(f"set USA price ${PRICE}")

    old_api = asc_lib.API
    try:
        asc_lib.API = V2
        availability = client.get(
            f"/inAppPurchases/{iap_id}/inAppPurchaseAvailability"
        ).get("data")
    except RuntimeError:
        availability = None
    finally:
        asc_lib.API = old_api
    if availability:
        print("availability exists")
    else:
        territories = [item["id"] for item in asc_lib.list_all(client, "/territories?limit=200")]
        client.post(
            "/inAppPurchaseAvailabilities",
            {
                "data": {
                    "type": "inAppPurchaseAvailabilities",
                    "attributes": {"availableInNewTerritories": True},
                    "relationships": {
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                        "availableTerritories": {
                            "data": [{"type": "territories", "id": item} for item in territories]
                        },
                    },
                }
            },
        )
        print(f"set availability in {len(territories)} territories")

    print("done")


if __name__ == "__main__":
    main()
