#!/bin/bash
# Export the named XCTest screenshot attachments used by the ASC renderer.
set -euo pipefail

UDID="${1:?missing simulator UDID}"
OUTPUT="${2:?missing output directory}"
mkdir -p "$OUTPUT"

TEMP_ROOT="$(mktemp -d /tmp/iron-splits-asc.XXXXXX)"
RESULT_BUNDLE="$TEMP_ROOT/capture.xcresult"
ATTACHMENTS="$TEMP_ROOT/attachments"

xcodebuild test \
  -project IronSplits.xcodeproj \
  -scheme IronSplits \
  -destination "id=$UDID" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:IronSplitsUITests/ASCReleaseCaptureUITests \
  -quiet

xcrun xcresulttool export attachments \
  --path "$RESULT_BUNDLE" \
  --output-path "$ATTACHMENTS" >/dev/null

python3 - "$ATTACHMENTS" "$OUTPUT" <<'PY'
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

attachments, output = map(Path, sys.argv[1:])
manifest = json.loads((attachments / "manifest.json").read_text(encoding="utf-8"))
records = manifest[0]["attachments"]
names = (
    "locker.png",
    "race-detail.png",
    "bests.png",
    "race-book.png",
    "race-book-compare.png",
    "race-book-export.png",
    "pattie.png",
    "settings.png",
)

for name in names:
    matches = [
        record
        for record in records
        if record.get("suggestedHumanReadableName", "").startswith(name)
    ]
    if len(matches) != 1:
        raise SystemExit(f"expected one XCTest attachment named {name}, found {len(matches)}")
    source = attachments / matches[0]["exportedFileName"]
    if source.suffix.lower() != ".png":
        raise SystemExit(f"attachment for {name} is not a PNG: {source}")
    shutil.copyfile(source, output / name)

print(f"exported {len(names)} named screenshots to {output}")
PY
