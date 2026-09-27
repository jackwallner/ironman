#!/usr/bin/env python3
"""Update legacy App Store locales that Fastlane no longer accepts."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import asc_lib


APP_VERSION = "1.1.0"
LEGACY_LOCALES = (
    "bn-BD",
    "gu-IN",
    "kn-IN",
    "ml-IN",
    "mr-IN",
    "or-IN",
    "pa-IN",
    "sl-SI",
    "ta-IN",
    "te-IN",
    "ur-PK",
)


def read_metadata(locale: str, filename: str) -> str:
    path = ROOT / "fastlane" / "metadata" / locale / filename
    return path.read_text(encoding="utf-8").strip()


def update_resource(client: asc_lib.ASCClient,
                    resource: str,
                    identifier: str,
                    current: dict,
                    values: dict[str, str]) -> bool:
    changed = {
        key: value
        for key, value in values.items()
        if current.get(key) != value
    }
    if not changed:
        return False
    client.request(
        "PATCH",
        f"/{resource}/{identifier}",
        {
            "data": {
                "type": resource,
                "id": identifier,
                "attributes": changed,
            }
        },
    )
    return True


def main() -> None:
    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, "com.jackwallner.ironman")
    version = next(
        (
            item
            for item in asc_lib.list_all(client, f"/apps/{app['id']}/appStoreVersions")
            if item.get("attributes", {}).get("versionString") == APP_VERSION
            and item.get("attributes", {}).get("appStoreState") in asc_lib.EDITABLE_STATES
        ),
        None,
    )
    if version is None:
        raise SystemExit(f"error: no editable App Store version {APP_VERSION}")

    version_localizations = asc_lib.list_all(
        client, f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations"
    )
    version_by_locale = {
        item.get("attributes", {}).get("locale"): item
        for item in version_localizations
    }

    updated_version = 0
    for locale in LEGACY_LOCALES:
        localization = version_by_locale.get(locale)
        if localization is None:
            raise SystemExit(f"error: App Store Connect is missing legacy locale {locale}")

        updated_version += update_resource(
            client,
            "appStoreVersionLocalizations",
            localization["id"],
            localization.get("attributes", {}),
            {
                "description": read_metadata(locale, "description.txt"),
                "keywords": read_metadata(locale, "keywords.txt"),
                "marketingUrl": read_metadata(locale, "marketing_url.txt"),
                "promotionalText": read_metadata(locale, "promotional_text.txt"),
                "supportUrl": read_metadata(locale, "support_url.txt"),
                "whatsNew": read_metadata(locale, "release_notes.txt"),
            },
        )

    print(f"updated legacy locale version records: {updated_version}")


if __name__ == "__main__":
    main()
