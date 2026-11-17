# Pre-submit review, 2026-11-07

Version under review: 1.1.5 (build 41), state "prepare for submission" in App Store Connect.

Live version: 1.1.4, "ready for distribution", last submission completed 2026-11-01 with build 40 (`ceddec7`).

## Scope

`git log -p -- project.yml` puts the 1.1.4 cycle at `cac091c` (version bump) through `ceddec7` (build 40). From build 40 to HEAD (`9bf20e8`), the app sources (`IronSplits/`, `Shared/`) did not change. The only change is the version and build number in `project.yml`, so the new binary has the same code as the live one.

To cover whichever 1.1.4 build actually shipped, the review also read the full 1.1.4 cycle, `cac091c~1..HEAD`, across app sources only (9 files, +128/-57):

- `IronSplits/IronSplitsApp.swift`, `Shared/Services/LockerStore.swift`: the screenshot seed is now persisted under `-ResetLocker -SeedScreenshotData`.
- `IronSplits/Views/RaceDetailView.swift`: `RaceFieldCache` now has a 24 hour disk copy in Caches.
- `IronSplits/Views/RootTabView.swift`: the Duo pane tab bar moved from a safe-area inset to a VStack below the content.
- `IronSplits/Views/LockerView.swift`, `IronSplits/Views/TriDesign.swift`: ranking chips wrap via `TriFlowLayout`. The light theme's secondary and tertiary ink are darker.
- `IronSplits/Views/Components.swift`, `IronSplits/Views/PointersView.swift`: `StatTile` gets an `onDark` caption, `SplitBar` is hidden from accessibility, and the Pattie invite title wraps.

## Checks

1. Crashes and data loss:
   - The new code has no force unwraps or subscripts.
   - `RaceFieldCache` is `@MainActor`.
   - The disk read is a chain of `try?` reads and falls back to the network on any failure.
   - `RaceResult` uses synthesized `Codable`, so the encode/decode round-trip is symmetric.
   - Nothing changed in how `LockerStorage` decodes saved data.
   - `TriFlowLayout` handles a nil proposal width and an empty subview list.
2. Purchase and paywall: no changes to `StoreService`, `ProGate`, `PaywallView` or RevenueCat config in the cycle. The paywall has the same Terms and Privacy links and live store pricing that passed review in 1.1.4.
3. State bugs: both new seed paths sit inside `#if DEBUG`, and so does `DebugScreenshotFixtures`. Release builds cannot reach them. Onboarding and settings keys are unchanged.
4. App Review risks: the cycle adds no new user-facing strings, links, prices or health claims. There is no debug UI in Release.
5. Backstop spot-check of the current tree (from the parallel review in `c74bfdd`):
   - `ProGate.everythingUnlocked` is `false`, and the only paid boundary is `raceBookUnlocked(isPro:)`.
   - `StoreService.start()` honours `FORCE_PRO` and simulator hydration only inside `#if DEBUG`. Release always configures RevenueCat and reads the `pro` entitlement through `apply(customerInfo:)`.
   - The paywall shows Restore Purchases plus Terms (Apple standard EULA) and Privacy links. It can be dismissed and closes itself once `isPro` flips.
   - There are no hard-coded prices in Swift sources.
   - Array subscripts are all behind count or emptiness guards: `RaceBook.comparisonPair`, the `RaceBookView` baseline picker, the PDF chart path, the `RaceAnalytics` year range and UUID formatting.

## Findings

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P2 | IronSplits/Views/RaceDetailView.swift:550 | A race field fetched while results are still posting (race day) is kept on disk for 24 hours, so the field stays partial for up to a day after a relaunch. Before 1.1.4 this only lasted for the session. | Not fixed: deliberate tradeoff in `ec6aa40` for published results, not a defect |
| P2 | IronSplits/Views/RaceDetailView.swift:558 | The whole field is JSON decoded (on cache read) and encoded and written (line 567, on store) on the main actor. A large full-distance field can cause a short hitch when a race opens. | Not fixed: performance only, no crash or data risk |

No P0 or P1 findings. No code changes were made.

## Tests

`gh-sim test --scheme IronSplits --only IronSplitsTests` ran on HEAD `9bf20e8` twice (Xcode 27.1, iPhone 17, iOS 27.2), and both runs passed with 104 passed, 0 failed, 0 skipped:

- `ironman@20261108-075727-7bd6-claude-mbpro12f0-1108-081556-2409` (this review)
- `ironman@20261108-075655-4b31-claude-mbprob070-1108-075831-15342` (the parallel review, GitHub Actions run 42497486554)

UI tests were not run because no app code changed since the live build.
