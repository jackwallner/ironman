# State machine fixes, 2026-11-24

Fixes for the claims in `state-machines-2026-11-24.md`, in ranked order. Every claim that survived the skeptical review failed its test on the starting commit `559e890` (run `ironman@20261124-133035-17ef-claude-imac8a12-1124-133707-25554`, GitHub run 45492925883), and every one is fixed.

**Counts: 3 fixed, 0 held, 0 skipped.** The 2 code-path items (C1, C2) are not counted; both are fixed under the rollouts that own them.

| Claim | Outcome | Commit | Regression test |
|---|---|---|---|
| M1. A restore that found nothing keeps its red line after Race Book unlocks | Fixed: `apply(customerInfo:)` clears `restoreError` when the account owns Race Book | `fix: clear the restore error line once Race Book unlocks` | `StateMachineRegressionTests.testRestoreErrorClearsWhenRaceBookUnlocks` (control `testControlRestoreErrorStaysWhileStillLocked`) |
| M2. Adding a second registration empties the Locker when the merged fetch fails | Fixed: `addContact` keeps the races on screen until the merged career arrives, so a failure lands in the existing "Couldn't update. Showing results last refreshed ..." path | `fix: keep the Locker loaded through a failed add and a re-claim` | `testFailedAddRegistrationKeepsTheCareerOnScreen` (control `testControlSuccessfulAddRegistrationMergesRaces`) |
| M3. Re-claiming the same athlete during a refresh leaves the Locker on a spinner | Fixed: `claim`, `addContact` and `unclaim` release the in-flight marker when they invalidate the old fetch, and only the newest refresh may clear it | `fix: keep the Locker loaded through a failed add and a re-claim` | `testReclaimDuringRefreshStillLoadsTheCareer` (control `testControlClaimingAnotherAthleteDuringRefreshLoadsThem`) |
| C1. Ask to Buy reads as a failed purchase (code path) | Fixed under Rollout A | `fix: show Ask to Buy as waiting for approval, not a failed purchase` | `PurchaseIssueTests` |
| C2. Write-review row never ends the asks; feedback ends them for good (code path) | Fixed under Rollout S | `feat: ask for a rating 3 seconds after opening a personal best` | `ReviewPromptTests` |

Stored data: none of the fixes changes a stored format. `locker.json`, `race-notes.json` and every UserDefaults key read the same as before; the star prompt keeps its existing keys (`ReviewPromptTests.testUpgradeKeepsStoredStateUnderTheSameKeys`). Nothing is reset or dropped.

Final suite: `gh-sim test --scheme IronSplits` at `0f01e39`, run `ironman@20261124-133035-17ef-claude-imac8a12-1124-151316-16323` (GitHub run 45508075590, Xcode 27.1, iPhone 17, iOS 27.2): **138 passed, 0 failed, 0 skipped**, including all 22 new tests (6 `StateMachineRegressionTests`, 4 `PurchaseIssueTests`, 12 `ReviewPromptTests`). No test failed, so nothing needed a check on the starting commit; the only failures on `559e890` were the 3 audit claims by design (run 45492925883). The UI test scheme (`IronSplitsUITests`, live feed) was not run; the one visible change is Settings' write-review row, now a `Button` that opens the same URL instead of a `Link`, same text and tint.

## Held for Jack

None from the audit.

## Skipped

None.
