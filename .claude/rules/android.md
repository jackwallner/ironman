---
paths:
  - "android/**"
  - "scripts/sync-android-assets.py"
---

# IM Tri Tracker Android rules

## Product and data

- Native Android code is in `android/`. Play application ID is
  `com.jackwallner.ironman`; display name is `IM Tri Tracker`.
- Show published full- and half-distance triathlon results only. Preserve the
  fast `startswith()` name query, explicit slower `contains()` fallback, full
  OData expansion, loose numeric decoding, zero-as-missing split handling, and
  race-kind-scoped rankings from the iOS implementation.
- The only paid surface is Race Book comparison and unlimited PDF/image export.
  Search, Locker results, splits, rankings, field context, notes, race detail,
  and the complete Tips library stay free. Use the RevenueCat `pro` entitlement
  as the single gate.
- Race Book is a one-time lifetime product, currently intended at USD $9.99,
  Play product ID `com.jackwallner.ironman.pro`. Do not add subscriptions or put
  prices in Play listing descriptions. Show the localised store price in the
  app before purchase.
- Locker, notes, and recent Explore profiles stay on-device. There is no
  developer results backend, user account, ad SDK, or location permission.
  Search sends a typed name and public contact/event IDs to the third-party
  timing service. RevenueCat receives purchase data. Keep Play Data Safety and
  the privacy policy consistent with these transfers.
- Keep the non-affiliation disclaimer in Settings. Do not use a WTC logo, M-DOT,
  or distance shorthand as branding.
- Google Play audience is adults 18+ only. Restrict users Google has determined
  to be minors. Do not market or classify this app for children.
- Ask Pattie is a deterministic tree from `docs/ask-pattie.json`. Pointer video
  files are downloaded before local playback. Voice files are Pattie's original
  recorded clips. Never synthesise her voice.

## Architecture (a screen-for-screen port of iOS)

- Match the iOS app: same screens, copy, tokens and flows. When iOS changes, port
  the change; do not let the two drift. `ui/theme/TriDesign.kt` holds the same
  colour values as `TriDesign.swift`, and `ui/theme/` holds the shared primitives
  (`TriScreen` nav bar, `TriSheet`, `InsetGroup`, chips, cards, `triPress`).
- One file per iOS view in `ui/screens/`; services in `data/`, pure models and
  analytics in `model/`. `AppGraph` builds every shared object once.
- Navigation is a per-tab `Navigator` stack (`ui/nav/`) with a floating tab bar.
  Sheets are `TriSheet` dialogs. State a covered screen must keep lives in
  `rememberRetained` / `ScreenModel`, which is released when the screen pops.
- Locker network work runs in the app scope (`LockerStore.refresh/claim` return
  a `Job`). Running it in a screen scope stranded the Locker on "Pulling your
  results" when onboarding left composition mid-claim.
- The feed's `@odata.nextLink` pages through `/web/wtc_results`, not
  `/web/results`. Both paths are accepted; rejecting the first broke "Against
  the field" for every event with more than 500 finishers.
- Debug-only launch extras (`DebugLaunchOptions`): `resetLocker`,
  `seedScreenshotData`, `pattieMode`, `forcePro`, `appearance`, `tipsMode`,
  `uiTest`. Release and `qa` builds compile a no-op.

## Build and signing

- Current Play target is API 36. Verify Google's target API requirement before
  each submission. `compileSdk` may move higher when the selected Compose
  libraries require newer compile stubs; do not raise `targetSdk` without
  reviewing Android behaviour changes.
- Apps targeting API 35 or higher must support 16 KB page-size devices. Check
  AAB `PAGE_ALIGNMENT_16K` and the ELF load alignment of every bundled native
  library, including SDK dependencies.
- Use JDK 17 and the checked-in Gradle wrapper. Run `xcodegen generate` only for
  iOS changes; Android Gradle owns `android/`.
- Debug RevenueCat configuration uses the Test Store key from ignored
  `android/local.properties`. Release configuration uses the Google Play
  public key from that local file. Never use the production `goog_` key in
  emulator tests. Never embed RevenueCat `sk_` secrets or Google service-account
  JSON credentials in source, assets, logs, or the AAB.
- Use Google Play App Signing. The upload keystore and passwords stay outside
  the repo, and release Gradle builds must fail if signing or the Play SDK key
  is missing. Increment `versionCode` for each Play upload.
- Store listing artwork belongs in `android/play-assets/`. Capture phone
  screenshots from the actual emulator build; keep emulator chrome, debug UI,
  test purchase states, and unlicensed marks out of listing artwork. Current
  Google guidance asks for at least two screenshots to publish and recommends
  four 1080 × 1920 portrait screenshots for app promotion. Screenshot files
  must be JPEG or 24-bit PNG without alpha, and each should have alt text.
  Check the current Console requirements before upload.

## Verification and release

Run all of the following before release:

```bash
cd android
./gradlew testDebugUnitTest
./gradlew connectedDebugAndroidTest
./gradlew assembleRelease
./gradlew bundleRelease
```

Connected tests require an API 36 Google Play AVD and intentionally exercise
the live timing feed. They run under the test orchestrator with
`clearPackageData`, so each starts from a clean install. Start the AVD on its own
console port for local Air testing (`-port 5580`, serial `emulator-5580`) and
set `ANDROID_SERIAL`. Other sessions on the Air drive emulators too. An
unqualified `adb emu kill` stops whichever emulator is attached to that ADB
server on port 5554. Remote Pro testing uses the separate connection and
serial documented below. `./gradlew assembleQa` builds the shipped R8
configuration with the debug key and no RevenueCat key, for emulator checks of
the minified app without touching the production project.

Capture and inspect screenshots in both light and dark mode. Check the built AAB's package name, version code, target SDK, signing
certificate, permissions, and bundled assets before upload.

Upload the signed AAB to internal testing first. Verify the Play-installed app,
Play Billing purchase and restore with licence testers, and RevenueCat's `pro`
entitlement. A Play service account may be needed to link RevenueCat to Google
Play. Ask before creating its credential or granting it Console access.

Complete the Play listing, privacy URL, target audience, content rating, app
access, ads, and Data Safety forms from actual app behaviour. Review the Play
pre-launch report before sending a production track to review. If the request is
to submit for review without launching publicly on approval, use managed
publishing when available.

## Content synchronisation

`android/app/src/main/assets/` contains offline copies of Ask Pattie, pointers,
voice metadata, and Pattie's original `.m4a` clips. After changing any source in
`docs/` or `IronSplits/Resources/PattieVoice/`, run
`python3 scripts/sync-android-assets.py` and commit the resulting Android asset
changes with the source update.

## Remote MacBook Pro AVD and Android tests

Use the common workflow in the `android-dev` skill section **Remote MacBook
Pro Play AVD**. Current Iron Splits host details:

- Bonjour name `Jacks-MacBook-Pro-2.local`, SSH user `jackwallner`. On
  2026-09-29 it resolved to `192.168.4.25`. The verified `known_hosts` entry is
  for that IP, so use `jackwallner@192.168.4.25` with strict host key checking.
  If the address changes, rediscover the host and verify the new fingerprint.
  Do not disable host key checks.
- Remote Android SDK: `/Users/jackwallner/Library/Android/sdk`. Use its
  absolute `adb` and `emulator` paths because they are not on Pro's default
  noninteractive SSH PATH.
- Pro's normal Java is 12. This project requires Java 17 for Gradle 9.7 and
  Android Gradle Plugin 9.4.1. Use Android Studio's JBR if available; otherwise
  download a temporary x86_64 Temurin 17 runtime from [Adoptium's JDK 17
  releases](https://adoptium.net/temurin/releases/?version=17), verify the
  published SHA-256, and remove it after testing. Do not install Java globally
  for this task.
- Play AVD `small_phone`: Google Play API 36.1 x86_64, serial
  `emulator-5554`, console port `5554`, 720 by 1280, 2 vCPUs, 2 GB RAM, 6 GB
  data partition, 256 MB heap. This AVD contains the signed-in Play account
  and Play-installed internal build. Preserve its data and app.
- Keep `small_phone` for manual Play installation and billing checks. Do not
  install this repo's Debug APK on it: both builds use
  `com.jackwallner.ironman`, but the Play and Debug signatures differ. Never
  uninstall the Play build to make instrumentation tests install.
- Connected tests must run on Pro itself. A forwarded remote ADB list showed
  the device to Air, but Gradle/UTP could not use it through the tunnel. Run
  Gradle over SSH from a temporary copy of the current `android/` worktree.
  Do not forward ADB or emulator console ports for Gradle tests.

### Start or reuse the Play AVD

Check the Pro ADB server before launching an emulator. If `small_phone` is
already running, reuse it. Otherwise start it headlessly from the Air:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 \
  '"/Users/jackwallner/Library/Android/sdk/platform-tools/adb" start-server'
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 \
  'nohup "/Users/jackwallner/Library/Android/sdk/emulator/emulator" -avd small_phone -port 5554 -no-window -no-audio -gpu host -no-boot-anim -no-metrics >/tmp/small_phone.log 2>&1 </dev/null &'
```

Run the boot check over SSH on Pro. Both conditions must pass before using the
device: ADB reports `emulator-5554 device`, and
`getprop sys.boot_completed` returns `1`.

```sh
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 \
  '"/Users/jackwallner/Library/Android/sdk/platform-tools/adb" devices -l; "/Users/jackwallner/Library/Android/sdk/platform-tools/adb" -s emulator-5554 shell getprop sys.boot_completed'
```

### Run connected tests on an isolated AVD

Pro has no repository checkout or Android `cmdline-tools`/`avdmanager`. From
the repo root on the Air, create a unique temporary copy of `android/` on Pro.
The commands below exclude generated files and ignored local properties, then
stream only the SDK path and Debug/Test Store key into the remote copy:

```sh
set -e -o pipefail
remote_test_dir="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 'mktemp -d /tmp/ironsplits-android-test.XXXXXX')"
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 "mkdir -p '$remote_test_dir/android'"
rsync -a -e 'ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes' \
  --exclude 'build/' --exclude '.gradle/' --exclude 'local.properties' \
  --exclude 'play-assets/' android/ \
  "jackwallner@192.168.4.25:$remote_test_dir/android/"
python3 - <<'PY' | ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 \
  "cat > '$remote_test_dir/android/local.properties' && chmod 600 '$remote_test_dir/android/local.properties'"
from pathlib import Path

properties = {}
for line in Path("android/local.properties").read_text().splitlines():
    if line.lstrip().startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    properties[key.strip()] = value.strip()

test_key = properties.get("REVENUECAT_TEST_KEY")
if not test_key:
    raise SystemExit("REVENUECAT_TEST_KEY is missing from ignored local.properties")

print("sdk.dir=/Users/jackwallner/Library/Android/sdk")
print(f"REVENUECAT_TEST_KEY={test_key}")
PY
```

Do not copy `REVENUECAT_PLAY_KEY`, the upload keystore path, or signing
passwords. Keep `remote_test_dir` for later cleanup. Never print the test key.

The Play AVD already owns the app package, so instrumentation uses a temporary
debug AVD named `ironsplits_agent_test` on port `5560`, serial
`emulator-5560`. The installed API 36.1 Play image is shared, but the new AVD
must have fresh userdata and no account. Pro has no `avdmanager`; create the
test AVD by copying only `small_phone.avd/config.ini`, changing `AvdId` and
`avd.ini.displayname`, and registering the new `.ini` with target
`android-36.1`. Do not copy `userdata-qemu.img`, snapshots, or any other
`small_phone` data. On Pro, run this guarded Python snippet to create the
configuration-only AVD. It refuses to overwrite an existing name:

```sh
python3 - <<'PY'
from pathlib import Path
import re

name = "ironsplits_agent_test"
avd_root = Path.home() / ".android" / "avd"
source_config = avd_root / "small_phone.avd" / "config.ini"
test_dir = avd_root / f"{name}.avd"
test_ini = avd_root / f"{name}.ini"

if test_dir.exists() or test_ini.exists():
    raise SystemExit(f"Refusing to overwrite existing AVD: {name}")

config = source_config.read_text()
for key, value in {
    "AvdId": name,
    "avd.ini.displayname": "Iron Splits Temporary Test",
}.items():
    config, count = re.subn(
        rf"^{re.escape(key)}=.*$",
        f"{key}={value}",
        config,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise SystemExit(f"Expected one {key} in small_phone config")

test_dir.mkdir()
(test_dir / "config.ini").write_text(config)
test_ini.write_text(
    "avd.ini.encoding=UTF-8\n"
    f"path={test_dir}\n"
    f"path.rel=avd/{name}.avd\n"
    "target=android-36.1\n"
)
PY
```

Start Pro's remote ADB server before launching the test AVD:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 \
  '"/Users/jackwallner/Library/Android/sdk/platform-tools/adb" start-server'
```

Launch this AVD headlessly on port `5560` from the Air:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 \
  'nohup "/Users/jackwallner/Library/Android/sdk/emulator/emulator" -avd ironsplits_agent_test -port 5560 -no-window -no-audio -gpu host -no-boot-anim -no-metrics >/Users/jackwallner/.android/avd/ironsplits_agent_test.avd/emulator.log 2>&1 </dev/null &'
```

Wait until ADB reports `emulator-5560 device` and
`getprop sys.boot_completed` returns `1`. The first boot took about 72 seconds;
do not start Gradle while the device is `offline` or still booting.

Run the tests in an SSH shell on Pro from the temporary checkout. Set
`JAVA_HOME` to the verified temporary JDK's `Contents/Home` and target the test
AVD serial:

```sh
ssh -tt -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25
```

Then, in that Pro shell, use the actual unique directory and JDK path created
for this run:

```sh
cd /tmp/ironsplits-android-test.<unique>/android
export JAVA_HOME="/tmp/ironsplits-android-test.<unique>/jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_SERIAL=emulator-5560
./gradlew --no-daemon testDebugUnitTest connectedDebugAndroidTest
```

Check Gradle output and `app/build/reports/androidTests/connected/debug/index.html`
for a nonzero executed count. A successful Gradle exit or a listed device
alone is not a test pass. Do not use `adb kill-server`; do not use the Air's local
`emulator-5580` for these remote commands. Avoid the zsh variable name `path`,
which is tied to `PATH`; use `remote_dir` or another distinct variable name.

After tests, stop the exact serial on Pro:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 \
  '"/Users/jackwallner/Library/Android/sdk/platform-tools/adb" -s emulator-5560 emu kill'
```

If you started the Play AVD, use its serial instead:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  jackwallner@192.168.4.25 \
  '"/Users/jackwallner/Library/Android/sdk/platform-tools/adb" -s emulator-5554 emu kill'
```

Wait until Pro `adb devices -l` is empty and confirm the emulator process has
exited. Then delete only
`ironsplits_agent_test.avd` and its sibling `.ini`, the temporary source tree,
and any temporary JDK. Use the exact paths created for this run. The production
Play AVD `small_phone` must remain registered with its userdata intact and be
shut down. Never pass `-wipe-data`.

### Play and RevenueCat state

Last verified 2026-09-29: Play internal testing release 1.0.0 (version code 1)
was active, production was inactive and not sent for review, and the one-person
internal tester list was selected for account-level License testing. The
Play-installed internal build was opened on `small_phone`, and the Play test
purchase granted RevenueCat entitlement `pro` in sandbox. Recheck Play Console
before relying on this state. The same test account owns the non-consumable
test purchase; do not attempt to buy it again. Use Restore Purchases to recheck
persistence.

To get a fresh opt-in URL, open Play Console **Test and release > Testing >
Internal testing > Testers** and copy **Join on the web**. Use the existing
Chrome profile on the Air, check the account shown on the invite, and accept
only for the configured tester account. Then open the Play Store listing on
Pro. Do not use the emulator's first-run Chrome flow for this step.

To verify RevenueCat, use the `revenuecat-cli` skill with the local credential
file and the `IM Tri Tracker` project. Confirm the Android customer has active
lookup key `pro`, the purchase product maps to
`com.jackwallner.ironman.pro`, and the purchase is `play_store` in `sandbox`
with status `owned`. Keep full customer IDs and purchase tokens out of chat and
logs.

### Last instrumentation run

On 2026-09-29, a fresh Luna max agent ran the Android suite on a temporary
API 36.1 AVD copied from the Play system-image configuration, with fresh
userdata. Unit tests passed: 22 total. Seven connected tests executed and all
seven failed in Espresso/Compose idle synchronization with
`NoSuchMethodException: android.hardware.input.InputManager.getInstance` on
API 36.1. The stack was `Espresso.onIdle` to `Compose EspressoLink.runUntilIdle`.
Treat connected instrumentation as blocked until this dependency/platform
failure is resolved and a later report passes. The test AVD and source/JDK
copies were removed, the Pro ADB device list is empty, and `small_phone` data
remains intact and shut down.
