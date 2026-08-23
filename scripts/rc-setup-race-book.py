#!/usr/bin/env python3
"""Wire the App Store Race Book product into RevenueCat.

The script is idempotent. It creates the App Store product record when needed,
attaches it to the lifetime package and to both the documented `pro`
entitlement and the older entitlement already present in this project.

The RevenueCat secret is read from RC_KEY or ~/.ironsplits_credentials and is
never written to the repository or printed.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://api.revenuecat.com/v2"
PROJECT_ID = "projd27c8a1b"
APP_ID = "appc01c87659d"
BUNDLE_ID = "com.jackwallner.ironman"
PRODUCT_ID = "com.jackwallner.ironman.pro"
PRODUCT_NAME = "Race Book"
PACKAGE_KEY = "$rc_lifetime"
PROBE_SUBSCRIBER = "ironsplits-release-readiness-probe"


def secret_key() -> str:
    value = os.environ.get("RC_KEY")
    if value:
        return value
    credentials = Path.home() / ".ironsplits_credentials"
    if credentials.exists():
        for raw_line in credentials.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if line.startswith("export "):
                line = line[7:]
            if line.startswith("REVENUECAT_SECRET_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("error: set RC_KEY or REVENUECAT_SECRET_KEY in ~/.ironsplits_credentials")


KEY = secret_key()


def request(method: str, path: str, body: dict | None = None) -> dict:
    request = urllib.request.Request(BASE + path, method=method)
    request.add_header("Authorization", f"Bearer {KEY}")
    request.add_header("Content-Type", "application/json")
    data = json.dumps(body).encode("utf-8") if body is not None else None
    try:
        with urllib.request.urlopen(request, data=data, timeout=120) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:800]
        raise RuntimeError(f"{method} {path} -> {error.code}: {detail}") from error


def ensure_product() -> dict:
    products = request("GET", f"/projects/{PROJECT_ID}/products?limit=100")["items"]
    product = next(
        (
            item
            for item in products
            if item.get("store_identifier") == PRODUCT_ID
            and item.get("app_id") == APP_ID
        ),
        None,
    )
    if product:
        if product.get("display_name") != PRODUCT_NAME:
            product = request(
                "POST",
                f"/projects/{PROJECT_ID}/products/{product['id']}",
                {"display_name": PRODUCT_NAME},
            )
            print(f"updated product name: {PRODUCT_NAME}")
        else:
            print(f"product exists: {PRODUCT_ID}")
        return product
    product = request(
        "POST",
        f"/projects/{PROJECT_ID}/products",
        {
            "store_identifier": PRODUCT_ID,
            "app_id": APP_ID,
            "type": "non_consumable",
            "display_name": PRODUCT_NAME,
        },
    )
    print(f"created product: {PRODUCT_ID}")
    return product


def ensure_entitlement(lookup_key: str, display_name: str) -> dict:
    entitlements = request("GET", f"/projects/{PROJECT_ID}/entitlements?limit=100")["items"]
    entitlement = next(
        (item for item in entitlements if item.get("lookup_key") == lookup_key),
        None,
    )
    if entitlement:
        return entitlement
    entitlement = request(
        "POST",
        f"/projects/{PROJECT_ID}/entitlements",
        {"lookup_key": lookup_key, "display_name": display_name},
    )
    print(f"created entitlement: {lookup_key}")
    return entitlement


def attach_to_entitlement(entitlement: dict, product: dict) -> None:
    attached = request(
        "GET",
        f"/projects/{PROJECT_ID}/entitlements/{entitlement['id']}/products?limit=100",
    )["items"]
    if any(item.get("id") == product["id"] for item in attached):
        print(f"entitlement has product: {entitlement['lookup_key']}")
        return
    request(
        "POST",
        f"/projects/{PROJECT_ID}/entitlements/{entitlement['id']}/actions/attach_products",
        {"product_ids": [product["id"]]},
    )
    print(f"attached product to entitlement: {entitlement['lookup_key']}")


def ensure_package(product: dict) -> None:
    offerings = request("GET", f"/projects/{PROJECT_ID}/offerings?limit=100")["items"]
    offering = next((item for item in offerings if item.get("is_current")), None)
    if offering is None:
        raise SystemExit("error: RevenueCat has no current offering")
    packages = request(
        "GET",
        f"/projects/{PROJECT_ID}/offerings/{offering['id']}/packages?limit=100",
    )["items"]
    package = next((item for item in packages if item.get("lookup_key") == PACKAGE_KEY), None)
    if package is None:
        package = request(
            "POST",
            f"/projects/{PROJECT_ID}/offerings/{offering['id']}/packages",
            {"lookup_key": PACKAGE_KEY, "display_name": PRODUCT_NAME},
        )
        print(f"created package: {PACKAGE_KEY}")
    elif package.get("display_name") != PRODUCT_NAME:
        package = request(
            "POST",
            f"/projects/{PROJECT_ID}/packages/{package['id']}",
            {"display_name": PRODUCT_NAME},
        )
        print(f"updated package name: {PRODUCT_NAME}")
    attached = request(
        "GET", f"/projects/{PROJECT_ID}/packages/{package['id']}/products?limit=100"
    )["items"]
    if any(item.get("product", {}).get("id") == product["id"] for item in attached):
        print(f"package has product: {PACKAGE_KEY}")
        return
    request(
        "POST",
        f"/projects/{PROJECT_ID}/packages/{package['id']}/actions/attach_products",
        {"products": [{"product_id": product["id"], "eligibility_criteria": "all"}]},
    )
    print(f"attached product to package: {PACKAGE_KEY}")


def verify_public_offering() -> None:
    credentials = Path.home() / ".ironsplits_credentials"
    public_key = os.environ.get("RC_PUBLIC_KEY")
    if not public_key and credentials.exists():
        for raw_line in credentials.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if line.startswith("export "):
                line = line[7:]
            if line.startswith("REVENUECAT_PUBLIC_KEY="):
                public_key = line.split("=", 1)[1].strip().strip('"').strip("'")
                break
    if not public_key:
        raise SystemExit("error: set RC_PUBLIC_KEY or REVENUECAT_PUBLIC_KEY in ~/.ironsplits_credentials")

    request_url = (
        f"https://api.revenuecat.com/v1/subscribers/{PROBE_SUBSCRIBER}/offerings"
    )
    http_request = urllib.request.Request(request_url)
    http_request.add_header("Authorization", f"Bearer {public_key}")
    http_request.add_header("X-Platform", "ios")
    with urllib.request.urlopen(http_request, timeout=60) as response:
        payload = json.loads(response.read())
    current_id = payload.get("current_offering_id")
    current = next(
        (item for item in payload.get("offerings", []) if item.get("identifier") == current_id),
        None,
    )
    packages = current.get("packages", []) if current else []
    identifiers = {
        package.get("platform_product_identifier")
        for package in packages
    }
    print(f"public current offering packages: {len(packages)}")
    if PRODUCT_ID not in identifiers:
        raise SystemExit(
            "error: RevenueCat public iOS offering does not contain the App Store Race Book product"
        )
    print(f"public offering contains: {PRODUCT_ID}")


def main() -> None:
    apps = request("GET", f"/projects/{PROJECT_ID}/apps")["items"]
    app = next((item for item in apps if item.get("id") == APP_ID), None)
    if app is None or app.get("app_store", {}).get("bundle_id") != BUNDLE_ID:
        raise SystemExit("error: RevenueCat App Store app does not match the app bundle")
    product = ensure_product()
    for lookup_key, display_name in (("pro", "Iron Splits+"), ("Ironman App Pro", "Ironman App Pro")):
        attach_to_entitlement(ensure_entitlement(lookup_key, display_name), product)
    ensure_package(product)
    verify_public_offering()
    print("done")


if __name__ == "__main__":
    main()
