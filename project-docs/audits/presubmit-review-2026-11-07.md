# Pre-submit review, 1.1.5 (build 41), 2026-11-07

## Scope

- Live App Store version: **1.1.4 build 40** (App Store Connect version
  `3ffc678e`, state READY_FOR_DISTRIBUTION, build `bbfc2fe7` = 40).
- Build 40 was cut at `ceddec7` ("chore: bump build 39 to 40", uploaded
  2026-11-01 12:34 PT). Candidate is `origin/main` at `9bf20e8` (1.1.5 build 41).
- `git diff ceddec7 9bf20e8` touches only `project.yml` (MARKETING_VERSION
  1.1.4 to 1.1.5, CURRENT_PROJECT_VERSION 40 to 41) and `qa/backlog.jsonl`,
  `qa/ledger.jsonl`. **No app source, resource, Info.plist or entitlement
  changed.** The binary going to review is the approved 1.1.4 code under a new
  version number.

Because the diff has no app code, there were no changes to review in the
requested order (crashes, purchase paths, state bugs, App Review risk). As a
backstop I spot-checked the areas where a regression would hurt most, on the
current tree:

- `ProGate.everythingUnlocked` is `false`; the only paid boundary is
  `raceBookUnlocked(isPro:)`.
- `StoreService.start()` honours `FORCE_PRO` and simulator hydration only inside
  `#if DEBUG`; Release always configures RevenueCat and reads the `pro`
  entitlement through `apply(customerInfo:)`.
- Paywall: Restore Purchases, Terms (Apple standard EULA) and Privacy links are
  present, the sheet can be dismissed, and it auto-dismisses once `isPro` flips.
  No hard-coded prices in Swift sources.
- Array subscripts (`RaceBook.comparisonPair`, `RaceBookView` baseline picker,
  PDF chart path, `RaceAnalytics` year range, UUID formatting) are all behind
  count or emptiness guards.

## Findings

| Severity | File:line | What happens | Status |
| --- | --- | --- | --- |
| none | n/a | No app changes since the live version, and the spot-check found nothing definitely broken. | n/a |

## Tests

Unit tests (`IronSplitsTests`, scheme `IronSplits`) were run on GitHub's Macs
with `gh-sim test --scheme IronSplits --only IronSplitsTests`: run
`ironman@20261108-075655-4b31-claude-mbprob070-1108-075831-15342`
(GitHub Actions run 42497486554, Xcode 27.1, iPhone 17 on iOS 27.2).
Result: **passed, 104 passed, 0 failed, 0 skipped.**
