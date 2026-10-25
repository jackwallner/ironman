#!/bin/bash
# xcodegen generate, plus the one thing xcodegen can't express.
#
# StoreKit Testing is what makes the paywall renderable on a simulator at all
# (see the ios-dev skill). XcodeGen only writes a StoreKitConfigurationFileReference
# into the scheme's LaunchAction (its spec has no key for the TestAction) and
# a UI test launches the app through the TestAction. Without the patch every
# headless paywall shot is the "Couldn't Load Plans" empty state, which
# exercises none of the layout worth checking.
#
# Bare `xcodegen generate` now does the same through project.yml's postGenCommand.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/.."

xcodegen generate  # postGenCommand runs scripts/patch-storekit-test-action.sh
