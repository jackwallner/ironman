#!/bin/bash
# Export the named XCTest screenshot attachments used by the ASC renderer.
set -euo pipefail

UDID="${1:?missing simulator UDID}"
OUTPUT="${2:?missing output directory}"
mkdir -p "$OUTPUT"
find "$OUTPUT" -maxdepth 1 -type f -name '*.png' -delete
agent-sim boot ironsplits >/dev/null
xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularBars 4 \
  --wifiBars 3

TEMP_ROOT="$(mktemp -d /tmp/iron-splits-asc.XXXXXX)"
RESULT_BUNDLE="$TEMP_ROOT/capture.xcresult"
ATTACHMENTS="$TEMP_ROOT/attachments"

xcodebuild test \
  -project IronSplits.xcodeproj \
  -scheme IronSplitsUITests \
  -destination "id=$UDID" \
  -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
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
    "rankings.png",
    "race-detail.png",
    "race-book.png",
    "explore.png",
    "pattie.png",
)

for name in names:
    expected_stem = Path(name).stem
    matches = [
        record
        for record in records
        if Path(record.get("suggestedHumanReadableName", "")).stem.startswith(expected_stem + "_")
    ]
    if len(matches) != 1:
        raise SystemExit(f"expected one XCTest attachment named {name}, found {len(matches)}")
    source = attachments / matches[0]["exportedFileName"]
    if source.suffix.lower() != ".png":
        raise SystemExit(f"attachment for {name} is not a PNG: {source}")
    shutil.copyfile(source, output / name)

print(f"exported {len(names)} named screenshots to {output}")
PY
