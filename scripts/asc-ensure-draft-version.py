#!/usr/bin/env python3
"""Find or create the editable App Store Connect version for this app."""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from asc_lib import (  # noqa: E402
    ASCClient,
    bearer_token,
    bundle_id_from_appfile,
    ensure_draft_version,
    find_app,
    find_live_version,
    load_credentials,
    load_state,
    save_state,
)


def main() -> None:
    preferred = os.environ.get("ASC_DRAFT_VERSION") or os.environ.get("ASC_APP_VERSION")
    state = load_state()
    if preferred is None and state.get("draftVersion"):
        preferred = state["draftVersion"]

    key_id, issuer_id, key_path = load_credentials()
    client = ASCClient(bearer_token(key_id, issuer_id, key_path))
    app = find_app(client, bundle_id_from_appfile())
    live = find_live_version(client, app["id"])
    draft = ensure_draft_version(client, app["id"], preferred)

    version = draft["attributes"]["versionString"]
    state_name = draft["attributes"].get("appStoreState", "unknown")
    live_version = live["attributes"]["versionString"] if live else None
    save_state(version, live_version, app["id"])

    print(f"draftVersion={version} ({state_name})")
    if live_version:
        print(f"liveVersion={live_version}")
    print(f"export ASC_APP_VERSION='{version}'")


if __name__ == "__main__":
    main()
