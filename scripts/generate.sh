#!/bin/bash
# xcodegen generate, plus the one thing xcodegen can't express.
#
# StoreKit Testing is what makes the paywall renderable on a simulator at all
# (see the ios-dev skill). XcodeGen only writes a StoreKitConfigurationFileReference
# into the scheme's LaunchAction (its spec has no key for the TestAction) and
# a UI test launches the app through the TestAction. Without this patch every
# headless paywall shot is the "Couldn't Load Plans" empty state, which
# exercises none of the layout worth checking.
#
# Use this instead of bare `xcodegen generate`.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/.."

SCHEME="IronSplits.xcodeproj/xcshareddata/xcschemes/IronSplits.xcscheme"
CONFIG="../../IronSplits/Services/Products.storekit"

xcodegen generate

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
  echo "==> Patched StoreKit configuration into the scheme's TestAction."
fi
