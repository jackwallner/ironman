#!/usr/bin/env python3
"""Restore the IM Tri Tracker name in the editable App Store Connect metadata."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import asc_lib


BUNDLE_ID = "com.jackwallner.ironman"
PUBLIC_NAME = "IM Tri Tracker"


def patch_app_name(client: asc_lib.ASCClient, app: dict) -> None:
    if app["attributes"].get("name") == PUBLIC_NAME:
        print("ASC app name already matches")
        return
    try:
        client.request(
            "PATCH",
            f"/apps/{app['id']}",
            {
                "data": {
                    "type": "apps",
                    "id": app["id"],
                    "attributes": {"name": PUBLIC_NAME},
                }
            },
        )
    except RuntimeError as error:
        if "ATTRIBUTE.NOT_ALLOWED" not in str(error):
            raise
        print("ASC app-record name is immutable; using version localization name")
        return
    print(f"updated ASC app name: {PUBLIC_NAME}")


def update_app_info_localizations(
    client: asc_lib.ASCClient, app: dict, version: dict
) -> None:
    metadata_root = asc_lib.ROOT / "fastlane" / "metadata"
    infos = asc_lib.list_all(client, f"/apps/{app['id']}/appInfos")
    if not infos:
        raise SystemExit("error: no ASC app info resource found")
    target_state = version.get("attributes", {}).get("appStoreState")
    info = next(
        (
            item
            for item in infos
            if item.get("attributes", {}).get("state") == target_state
        ),
        None,
    )
    if info is None:
        editable = [
            item
            for item in infos
            if item.get("attributes", {}).get("state") != "READY_FOR_DISTRIBUTION"
        ]
        if len(editable) != 1:
            raise SystemExit("error: could not identify the editable ASC app info")
        info = editable[0]
    localizations = asc_lib.list_all(
        client, f"/appInfos/{info['id']}/appInfoLocalizations"
    )
    updated = 0
    for localization in localizations:
        locale = localization.get("attributes", {}).get("locale")
        name_path = metadata_root / str(locale) / "name.txt"
        if not name_path.is_file():
            continue
        name = name_path.read_text(encoding="utf-8").strip()
        if not name or localization.get("attributes", {}).get("name") == name:
            continue
        client.request(
            "PATCH",
            f"/appInfoLocalizations/{localization['id']}",
            {
                "data": {
                    "type": "appInfoLocalizations",
                    "id": localization["id"],
                    "attributes": {"name": name},
                }
            },
        )
        updated += 1
    print(f"updated ASC app-name localizations: {updated}")


def main() -> None:
    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    patch_app_name(client, app)

    versions = asc_lib.list_all(client, f"/apps/{app['id']}/appStoreVersions")
    version = next(
        (
            item
            for item in versions
            if item.get("attributes", {}).get("appStoreState") in asc_lib.EDITABLE_STATES
        ),
        None,
    )
    if version is None:
        raise SystemExit("error: no editable App Store version found")
    update_app_info_localizations(client, app, version)


if __name__ == "__main__":
    main()
