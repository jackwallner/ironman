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
the live timing feed. Capture and inspect screenshots in both light and dark
mode. Check the built AAB's package name, version code, target SDK, signing
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
