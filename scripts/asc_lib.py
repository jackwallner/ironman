"""Small App Store Connect API client used by the metadata scripts."""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import jwt
except ImportError:
    jwt = None

API = "https://api.appstoreconnect.apple.com/v1"
ROOT = Path(__file__).resolve().parent.parent
STATE_FILE = Path(__file__).resolve().parent / ".asc-state.json"

EDITABLE_STATES = frozenset(
    {
        "PREPARE_FOR_SUBMISSION",
        "DEVELOPER_REJECTED",
        "REJECTED",
        "METADATA_REJECTED",
        "WAITING_FOR_REVIEW",
    }
)


def load_credentials() -> tuple[str, str, str]:
    values = {
        "ASC_API_KEY_ID": os.environ.get("ASC_API_KEY_ID"),
        "ASC_ISSUER_ID": os.environ.get("ASC_ISSUER_ID"),
        "ASC_KEY_PATH": os.environ.get("ASC_KEY_PATH"),
    }
    if not all(values.values()):
        credentials_path = Path.home() / ".baseball_credentials"
        if credentials_path.exists():
            for raw_line in credentials_path.read_text(encoding="utf-8").splitlines():
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                normalized_key = key.strip().removeprefix("export ").strip()
                if normalized_key in values and not values[normalized_key]:
                    values[normalized_key] = os.path.expandvars(
                        value.strip().strip('"').strip("'")
                    )
    missing = [key for key, value in values.items() if not value]
    if missing:
        raise SystemExit("error: set " + ", ".join(missing))
    return values["ASC_API_KEY_ID"], values["ASC_ISSUER_ID"], values["ASC_KEY_PATH"]


def bearer_token(key_id: str, issuer_id: str, key_path: str) -> str:
    if jwt is None:
        raise SystemExit("error: install PyJWT and cryptography before using ASC scripts")
    issued_at = int(time.time())
    return jwt.encode(
        {
            "iss": issuer_id,
            "iat": issued_at,
            "exp": issued_at + 1200,
            "aud": "appstoreconnect-v1",
        },
        Path(key_path).read_text(encoding="utf-8"),
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


class ASCClient:
    def __init__(self, token: str):
        self.token = token

    def request(self, method: str, path: str, body: dict | None = None) -> dict:
        url = f"{API}{path}"
        data = json.dumps(body).encode("utf-8") if body is not None else None
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                raw = response.read().decode("utf-8")
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {path} -> {error.code}: {detail}") from error

    def get(self, path: str) -> dict:
        return self.request("GET", path)

    def post(self, path: str, body: dict) -> dict:
        return self.request("POST", path, body)


def list_all(client: ASCClient, path: str) -> list[dict]:
    items: list[dict] = []
    next_path = path
    while next_path:
        response = client.get(next_path)
        items.extend(response.get("data", []))
        next_url = response.get("links", {}).get("next")
        if not next_url:
            break
        if not next_url.startswith(API + "/"):
            raise RuntimeError("App Store Connect returned an unexpected pagination URL")
        next_path = next_url[len(API):]
    return items


def bundle_id_from_appfile() -> str:
    appfile = ROOT / "fastlane/Appfile"
    for line in appfile.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("app_identifier"):
            return line.split('"', 2)[1]
    raise SystemExit("error: could not read app_identifier from fastlane/Appfile")


def find_app(client: ASCClient, bundle_id: str) -> dict:
    encoded = urllib.parse.quote(bundle_id, safe="")
    apps = client.get(f"/apps?filter[bundleId]={encoded}").get("data", [])
    if not apps:
        raise SystemExit(f"error: no App Store Connect app for bundle id {bundle_id}")
    return apps[0]


def list_versions(client: ASCClient, app_id: str) -> list[dict]:
    return list_all(client, f"/apps/{app_id}/appStoreVersions")


def find_version_by_string(client: ASCClient, app_id: str, version: str) -> dict | None:
    return next(
        (
            item
            for item in list_versions(client, app_id)
            if item.get("attributes", {}).get("versionString") == version
        ),
        None,
    )


def find_editable_version(client: ASCClient, app_id: str) -> dict | None:
    versions = list_versions(client, app_id)
    return next(
        (
            item
            for item in versions
            if item.get("attributes", {}).get("appStoreState") in EDITABLE_STATES
        ),
        None,
    )


def find_live_version(client: ASCClient, app_id: str) -> dict | None:
    live = [
        item
        for item in list_versions(client, app_id)
        if item.get("attributes", {}).get("appStoreState") == "READY_FOR_SALE"
    ]
    return max(
        live,
        key=lambda item: item.get("attributes", {}).get("versionString", ""),
        default=None,
    )


def bump_version(version: str) -> str:
    parts = version.split(".")
    while len(parts) < 3:
        parts.append("0")
    try:
        parts[-1] = str(int(parts[-1]) + 1)
    except ValueError as error:
        raise SystemExit(f"error: invalid App Store version {version}") from error
    return ".".join(parts)


def create_draft_version(client: ASCClient, app_id: str, version: str) -> dict:
    body = {
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": version},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    return client.post("/appStoreVersions", body)["data"]


def ensure_draft_version(client: ASCClient, app_id: str, preferred: str | None = None) -> dict:
    if preferred:
        existing = find_version_by_string(client, app_id, preferred)
        if existing:
            state = existing.get("attributes", {}).get("appStoreState", "unknown")
            if state in EDITABLE_STATES:
                return existing
            raise SystemExit(
                f"error: requested App Store version {preferred} already exists "
                f"in non-editable state {state}; clear ASC_APP_VERSION and "
                "scripts/.asc-state.json to create the next draft"
            )
        return create_draft_version(client, app_id, preferred)

    editable = find_editable_version(client, app_id)
    if editable:
        return editable

    live = find_live_version(client, app_id)
    candidate = bump_version(live["attributes"]["versionString"] if live else "1.0.0")

    for _ in range(8):
        existing = find_version_by_string(client, app_id, candidate)
        if existing:
            candidate = bump_version(candidate)
            continue
        try:
            return create_draft_version(client, app_id, candidate)
        except RuntimeError as error:
            if preferred or ("already been used" not in str(error) and "ENTITY_ERROR" not in str(error)):
                raise
            candidate = bump_version(candidate)
    raise SystemExit("error: could not create a new draft App Store version")


def save_state(draft_version: str, live_version: str | None, app_id: str) -> None:
    STATE_FILE.write_text(
        json.dumps(
            {
                "appId": app_id,
                "draftVersion": draft_version,
                "liveVersion": live_version,
                "updatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def load_state() -> dict:
    if not STATE_FILE.exists():
        return {}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
