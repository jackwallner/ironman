#!/usr/bin/env python3
"""Query the race results feed from the command line.

Same contract the iOS app uses: an OData collection behind a proxy that signs
requests server-side. Useful for checking the feed is alive, for pulling an
athlete's history to eyeball against the app, and as the ingest half of the
Supabase cache described in backend/README.md.

    ./results_feed.py search "Pattie Wallner"
    ./results_feed.py athlete a508fd19-3e5e-45d2-9a18-47215c7bcb40
    ./results_feed.py event 3bd630ca-4c2a-4775-87bd-b0d2c2764c53 --json
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
import uuid

# Keep in step with docs/api-config.json, which is what the app reads.
CONFIG_URL = "https://jackwallner.github.io/ironman/api-config.json"
FALLBACK_CONFIG = {
    "proxyURL": "https://labs-v2.competitor.com/api/results-proxy",
    "proxyURLParameter": "url",
    "pageSizeParameter": "pageSize",
    "resultsURL": "https://api.competitor.com/web/results",
    "pageSize": 500,
    "maxPages": 12,
    "referer": "https://labs-v2.competitor.com/",
}

# An explicit $expand REPLACES the server default rather than adding to it, so
# every relation we read has to be named. Omitting wtc_ContactId here is what
# made the app's search return rows with no athlete on them.
EXPAND = ",".join([
    "wtc_EventId($select=wtc_name,wtc_eventdate,wtc_externaleventname)",
    "wtc_ContactId($select=contactid,firstname,lastname,fullname,address1_city,"
    "address1_stateorprovince,address1_country,gendercode)",
    "wtc_CountryRepresentingId($select=wtc_iso2,wtc_name)",
    "wtc_AgeGroupId($select=wtc_agegroupname)",
])

# Mirrors ResultsAPI.encodeODataValue. OData syntax characters stay literal;
# everything else is escaped exactly once inside the upstream URL, which is then
# escaped again as the proxy's `url` parameter.
_SAFE = "-._~()$/*"


def load_config() -> dict:
    try:
        with urllib.request.urlopen(CONFIG_URL, timeout=10) as response:
            return json.load(response)
    except Exception:
        return FALLBACK_CONFIG


def encode(value: str) -> str:
    return urllib.parse.quote(value, safe=_SAFE)


def request_url(config: dict, query: str, page_size: int | None = None) -> str:
    upstream = f"{config['resultsURL']}?{query}"
    params = {
        config["proxyURLParameter"]: upstream,
        config["pageSizeParameter"]: str(page_size or config["pageSize"]),
    }
    return f"{config['proxyURL']}?{urllib.parse.urlencode(params)}"


def fetch(config: dict, filter_: str, order_by: str | None = None,
          page_size: int | None = None, max_pages: int | None = None) -> list[dict]:
    query = "$filter=" + encode(filter_) + "&$expand=" + encode(EXPAND)
    if order_by:
        query += "&$orderby=" + encode(order_by)
    url = request_url(config, query, page_size)

    rows: list[dict] = []
    limit = min(max_pages or config["maxPages"], config["maxPages"])
    for _ in range(max(limit, 1)):
        request = urllib.request.Request(url, headers={
            "Accept": "application/json",
            "Referer": config["referer"],
        })
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.load(response)
        if "error" in payload:
            raise SystemExit(f"upstream rejected the request: {payload['error']}")
        rows.extend(payload.get("value", []))
        next_link = payload.get("@odata.nextLink")
        if not next_link:
            break
        params = {
            config["proxyURLParameter"]: next_link,
            config["pageSizeParameter"]: str(page_size or config["pageSize"]),
        }
        url = f"{config['proxyURL']}?{urllib.parse.urlencode(params)}"
    return rows


def escape_literal(value: str) -> str:
    return value.replace("'", "''")


def name_filter(term: str) -> str:
    words = [escape_literal(w) for w in term.replace(",", " ").split() if w][:3]
    if not words:
        raise SystemExit("give me a name to search for")
    clauses = [
        f"(contains(wtc_ContactId/firstname,'{w}') or contains(wtc_ContactId/lastname,'{w}'))"
        for w in words
    ]
    return " and ".join(clauses)


def require_guid(value: str) -> str:
    try:
        uuid.UUID(value)
    except ValueError:
        raise SystemExit(f"not a GUID: {value}")
    return value


def seconds(value) -> int | None:
    """0 is the feed's 'no data', not a time of zero."""
    if isinstance(value, str):
        value = value.replace(",", "")
    try:
        number = int(float(value))
    except (TypeError, ValueError):
        return None
    return number or None


def hms(value: int | None) -> str:
    if not value:
        return "—"
    hours, rest = divmod(value, 3600)
    minutes, secs = divmod(rest, 60)
    return f"{hours}:{minutes:02d}:{secs:02d}" if hours else f"{minutes}:{secs:02d}"


def print_results(rows: list[dict]) -> None:
    rows = sorted(rows, key=lambda r: (r.get("wtc_EventId") or {}).get("wtc_eventdate") or "", reverse=True)
    for row in rows:
        event = row.get("wtc_EventId") or {}
        date = (event.get("wtc_eventdate") or "")[:10] or "----------"
        legs = "  ".join(
            f"{label} {hms(seconds(row.get(key)))}"
            for label, key in (("S", "wtc_swimtime"), ("B", "wtc_biketime"), ("R", "wtc_runtime"))
        )
        bib = row.get("wtc_bibnumber")
        group = row.get("_wtc_agegroupid_value_formatted") or ""
        place = row.get("wtc_finishrankgroup")
        status = "" if row.get("wtc_finisher") and not row.get("wtc_dnf") else "  DNF"
        print(f"{date}  {hms(seconds(row.get('wtc_finishtime'))):>9}  {legs}  "
              f"bib {bib or '—':<6} {group}{f' #{place}' if place else ''}{status}  {event.get('wtc_name')}")


def print_athletes(rows: list[dict]) -> None:
    people: dict[str, dict] = {}
    for row in rows:
        contact = row.get("wtc_ContactId") or {}
        contact_id = contact.get("contactid")
        if not contact_id:
            continue
        entry = people.setdefault(contact_id, {"name": contact.get("fullname"), "count": 0,
                                               "city": contact.get("address1_city"),
                                               "state": contact.get("address1_stateorprovince")})
        entry["count"] += 1
    for contact_id, entry in sorted(people.items(), key=lambda kv: -kv[1]["count"]):
        location = ", ".join(p for p in (entry["city"], entry["state"]) if p)
        print(f"{entry['count']:>3}  {entry['name']:<28} {location:<24} {contact_id}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true", help="dump raw rows instead of a table")
    sub = parser.add_subparsers(dest="command", required=True)

    search = sub.add_parser("search", help="find athletes by name")
    search.add_argument("name")

    athlete = sub.add_parser("athlete", help="one athlete's whole history, by contact GUID")
    athlete.add_argument("contact_id")

    event = sub.add_parser("event", help="every result in one event, by event GUID")
    event.add_argument("event_id")

    args = parser.parse_args()
    config = load_config()

    if args.command == "search":
        rows = fetch(config, name_filter(args.name), page_size=250, max_pages=2)
        print(json.dumps(rows, indent=2) if args.json else "", end="")
        if not args.json:
            print_athletes(rows)
    elif args.command == "athlete":
        rows = fetch(config, f"wtc_ContactId/contactid eq {require_guid(args.contact_id)}",
                     order_by="wtc_EventId/wtc_eventdate desc")
        print(json.dumps(rows, indent=2) if args.json else "", end="")
        if not args.json:
            print_results(rows)
    else:
        rows = fetch(config,
                     f"_wtc_eventid_value eq {require_guid(args.event_id)} "
                     "and wtc_AgeGroupId/wtc_agegroupname ne 'ODIV'",
                     order_by="wtc_finishrankoverall")
        if args.json:
            print(json.dumps(rows, indent=2))
        else:
            print(f"{len(rows)} results")
            print_results(rows[:25])


if __name__ == "__main__":
    sys.exit(main())
