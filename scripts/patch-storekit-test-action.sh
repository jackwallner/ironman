#!/bin/bash
# Puts the StoreKit configuration on the TestAction of both schemes.
#
# XcodeGen only writes a StoreKitConfigurationFileReference into the LaunchAction
# and a UI test launches the app through the TestAction, so without this every
# headless paywall is the "Couldn't Load Plans" empty state. project.yml runs
# this as XcodeGen's postGenCommand, so a bare `xcodegen generate` (the release
# gate runs one) gets it too.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/.."

CONFIG="../../IronSplits/Services/Products.storekit"


for SCHEME in IronSplits.xcodeproj/xcshareddata/xcschemes/{IronSplits,IronSplitsUITests}.xcscheme; do
if grep -q "StoreKitConfigurationFileReference" "$SCHEME" && \
   /usr/bin/python3 - "$SCHEME" "$CONFIG" <<'PY'
import re, sys

path, config = sys.argv[1], sys.argv[2]
with open(path) as handle:
    scheme = handle.read()

reference = (
    '      <StoreKitConfigurationFileReference\n'
    f'         identifier = "{config}">\n'
    '      </StoreKitConfigurationFileReference>\n'
)

test_action = re.search(r"   <TestAction\b.*?   </TestAction>\n", scheme, re.S)
if test_action is None:
    sys.exit("no TestAction in the scheme")

block = test_action.group(0)
if "StoreKitConfigurationFileReference" in block:
    sys.exit(0)

patched = block.replace("   </TestAction>\n", reference + "   </TestAction>\n")
with open(path, "w") as handle:
    handle.write(scheme.replace(block, patched))
PY
then
  echo "==> Patched StoreKit configuration into $(basename "$SCHEME" .xcscheme)'s TestAction."
fi
done
