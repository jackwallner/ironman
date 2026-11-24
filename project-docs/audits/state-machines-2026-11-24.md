# State machine audit, 2026-11-24

Scope: the IM Tri Tracker iOS app (one app target; no widgets, Watch app, App Intents or notifications, so no scheduled or pending requests exist to reconcile). Android is out of scope. Audited from committed code at `559e890`. No app code was changed for the audit itself.

**Summary: 3 bugs proved by failing test, 2 code path only (not proved, both fixed under the rollouts that own them).** Plus 5 product calls (not counted).

Evidence run: `gh-sim test --scheme IronSplits --only IronSplitsTests/StateMachineAuditRepro` on the starting commit, run `ironman@20261124-133035-17ef-claude-imac8a12-1124-133707-25554` (GitHub run 45492925883, Xcode 27.1, iPhone 17, iOS 27.2). Result: 6 tests, 3 passed (the controls), 3 failed (the claims). The repro suite is `state-machines-2026-11-24-repro.swift` beside this file (copy it into `IronSplitsTests/` to run it).

Seams used: `LockerStore(api:)` with an injected `ResultsProviding` (the suite's `ScriptedFeed` answers each call when the test says so, so refreshes can overlap the way they do on a slow feed), `LockerStorage` saved and restored per test, `StoreService.shared.apply(customerInfo:)` with a `CustomerInfo` decoded from the backend's JSON shape, and `restorePurchases()` on a simulator where RevenueCat is never configured (it sets the restore error line without touching any RevenueCat project). Seams that do not exist: an injectable purchases client, so the purchase call itself (Ask to Buy) is code path only.

## Bugs ranked by impact

| ID | Bug | What the user sees | Promise | User route | Impact | Evidence | file:line |
|---|---|---|---|---|---|---|---|
| M1 | A restore that found nothing keeps its red line after Race Book unlocks | Settings shows "Race Book is unlocked" with, directly under it, "No Race Book purchase was found for this Apple ID." in red, until the app is killed. | The two lines contradict each other on the same screen; `SettingsView.swift:113-131` renders `store.restoreError` whatever `isPro` is. | Settings, Race Book, Restore purchases (nothing to restore yet). See Race Book, Unlock Race Book, buy. The paywall closes on unlock and Settings shows both lines. The same happens when an Ask to Buy is approved later in the session. | Every buyer who tries Restore before buying in the same session, a common order for someone who is not sure they bought it before. Cost: a false "no purchase" message beside a purchase they just paid for. | Test `testRestoreErrorClearsWhenRaceBookUnlocks`: preconditions (locked, restore error set, then `isPro` true after the purchase) asserted first. Failed with `XCTAssertNil failed: "Purchases are unavailable in simulator builds."` (on a simulator the restore writes its simulator line into the same `restoreError` field that holds "No Race Book purchase was found" on a device). Control `testControlRestoreErrorStaysWhileStillLocked` passed. | `StoreService.swift:513-523` (`apply` never clears `restoreError`), `:482` |
| M2 | Adding a second registration empties the Locker when the merged fetch fails | Locker toolbar, More, Add another registration, pick the other record: if the feed times out, the whole career disappears and the Locker reads "Couldn't load your races". | `LockerStore.swift:3-9`: "an athlete opening their locker on a start line with one bar of signal should still see their bib numbers"; `:113-117`: "A refresh that fails after we already have a cached locker is not an error worth interrupting anyone over. The screen is still correct". | Locker, More (ellipsis), Add another registration, search, tap the other record. `addContact` sets `results = []` before the fetch (`:97`), so a failed fetch has nothing to fall back on. | Athletes whose career is split across two contact records (the reason the feature exists, see `Athlete.contactIDs`) when the feed is slow: the contact query is the feed's slow path. Cost: the career vanishes in-session until Try again succeeds or the app relaunches (the disk copy is untouched). | Test `testFailedAddRegistrationKeepsTheCareerOnScreen`: preconditions (2 races loaded, the merged fetch was the call that failed) asserted first. Failed with `("0") is not equal to ("2") - a failed fetch must not empty a Locker that had races`. Control `testControlSuccessfulAddRegistrationMergesRaces` passed. | `LockerStore.swift:83-101` |
| M3 | Re-claiming the same athlete while a refresh is in flight leaves the Locker on a spinner | "Pulling your results…" with no races, until the athlete finds More, Refresh results or relaunches. | `LockerStore.swift:28-29`: the generation counter "Invalidates an older network response when the user claims another athlete ... or starts a newer refresh"; the newer claim's own fetch is the one that must run. | Locker, More, Refresh results (or pull to refresh, or the launch refresh), then while it runs: Change, search your own name, tap yourself, Replace. `claim` bumps the generation (so the in-flight answer is dropped) but the in-flight marker for the same contact ids makes the claim's own refresh return at once (`:122`). | Narrow: someone re-picking themselves (a natural "reload" gesture) within the few seconds a refresh takes. Cost: an empty Locker on a spinner; no data lost (disk copy untouched). | Test `testReclaimDuringRefreshStillLoadsTheCareer`: precondition (claimed and loaded) asserted first. Failed with `("loading") is not equal to ("loaded") - the Locker sits on a spinner with no races`. Control `testControlClaimingAnotherAthleteDuringRefreshLoadsThem` passed. | `LockerStore.swift:68-75`, `:118-126` |
| C1 | (Code path, not proved) Ask to Buy reads as a failed purchase | A child account taps Unlock Race Book, Apple sends the request to a parent, and the paywall shows "Couldn't complete the purchase. Please try again." (or an older unrelated load error). | `PaywallView.swift:501-503`: "Ask-to-Buy / deferred payment: nothing is unlocked yet and no error occurred, tell the user instead of going silent." | Paywall, Unlock Race Book, Ask to Buy on a Family Sharing child account. RevenueCat with StoreKit 2 throws `ErrorCode.paymentPendingError` for this, so `.pending` is never returned and the catch at `:507-508` runs. | Family Sharing child accounts. | Not run: `Purchases.shared` is not injectable. Fixed and covered by mapping tests under Rollout A. | `StoreService.swift:420`, `PaywallView.swift:507-508` |
| C2 | (Code path, not proved) The Settings write-review row does not end the automatic star prompt, and sending feedback ends it for good | Someone who already wrote a review keeps getting Apple's prompt; someone who sent feedback never gets it again. | `ReviewPromptTracker.swift:9-13` defines `openedWriteReview` and `markOpenedWriteReview()`, which nothing called; `Link` at `SettingsView.swift:178` opens the page without it. | Settings, About, Write a review on the App Store. | Everyone who taps that row. | `markOpenedWriteReview` had no caller (grep). Fixed and covered under Rollout S. | `SettingsView.swift:178`, `ReviewPromptTracker.swift:214-217` |

## Skeptical self-review (phase 2)

Re-read as an independent reviewer, against the shipping UI only.

- M1 survives. Both halves are reachable on a device: Restore with nothing to restore writes "No Race Book purchase was found for this Apple ID." (`StoreService.swift:482`), and the purchase or a later Ask to Buy approval only flips `isPro` (`:513-523`). Settings renders the line with no `isPro` check (`SettingsView.swift:129`). The test's precondition proves `isPro` really turned true from a decoded `CustomerInfo`, so it is not a broken setup.
- M2 survives. Locker, More, Add another registration is a shipping menu item (`LockerView.swift:76-80`), and the merged fetch is a fresh network call that can time out after the search succeeded. The test's precondition proves the merged ids were requested.
- M3 survives, ranked last. The route needs the re-claim inside the refresh's few seconds, but Change and Refresh results sit side by side in the Locker toolbar. The toolbar's Refresh results recovers it, so it is a stuck screen, not lost data.
- C1 and C2 stay code path only and are not counted. Both are fixed by the rollouts that own them, with their own tests.

## Product calls (not counted: documented, or no cited promise)

1. A claim or added registration whose first fetch fails is not saved (`persist()` only runs on success, `LockerStore.swift:146`). Replacing athlete A with B offline shows B with an error, and the next cold launch brings A back from disk. Arguably the safer behaviour; not a promise either way.
2. `claim` keeps the previous athlete's `lastRefreshed`, so a failed first fetch for the new athlete leaves the 30-minute non-forced refresh window shut on the old timestamp. The failure screen's Try again forces a refresh, so nothing is stuck.
3. `isPro` is not persisted (`StoreService.swift:273-278`); a buyer cold-launching offline relies on RevenueCat's cached customer info reaching the delegate. SDK behaviour, not verified here.
4. The first-conversion record (`ConversionDiagnostics.recordConversion`) is written only on a direct purchase result; an Ask to Buy approved later through the delegate never writes `converted_*` attributes. Attribution only.
5. Restore purchases in Settings is not disabled while a restore runs; a double tap runs two restores. Harmless.

## State machines

### SM1. Locker (`LockerStore`)

State: `athlete: Athlete?`, `results`, `state` (`idle`, `loading`, `loaded`, `failed`), `lastRefreshed`, `refreshWarning`, `refreshGeneration`, `refreshingContactIDs`, plus the on-disk `locker.json` snapshot.

Invariants:
- L1. A Locker that has shown races keeps showing races when a fetch fails (doc comment `:113-117`).
- L2. Only the newest fetch may write `results` (generation guard).
- L3. Every claim or added registration issues its own fetch.
- L4. The disk snapshot changes only on a successful fetch.

| From | Event | To | Invariant |
|---|---|---|---|
| no athlete | claim | loading (empty), fetch | L3 |
| loading | fetch ok | loaded, saved | L4 |
| loading (empty) | fetch fails | failed, not saved | product call 1 |
| loaded | refresh fails | loaded plus warning | L1 |
| loaded | add registration | loading (emptied), fetch | L1 broken on failure (M2) |
| loaded, refresh in flight | claim same athlete | loading (empty), no fetch | L3 broken (M3) |
| loaded, refresh in flight | claim another athlete | loading (empty), fetch; old answer dropped | L2 |
| any | remove athlete | no athlete, snapshot deleted; notes kept (promised by the Replace alert) | none |

### SM2. Race Book purchase (`StoreService`, `PaywallView`)

State: `isConfigured`, `customerInfo`, `isPro`, `purchaseInFlight`, `products`, `currentOffering`, `lastError`, `restoreError`; per paywall `isPurchasing`, `errorMessage`, `restoreMessage`.

Invariants: P1 `isPro == customerInfo.hasProEntitlement` after every `apply`; P2 a purchase's message comes from that purchase, never from the shared `lastError`; P3 a pending Ask to Buy is shown as waiting; P4 no "nothing found" line beside an unlocked Race Book.

| From | Event | To | Invariant |
|---|---|---|---|
| locked | purchase ok | unlocked, paywall closes | P1 |
| locked | user cancels | locked, no message | none |
| locked | Ask to Buy (`paymentPendingError`) | locked, "Couldn't complete the purchase" | P3 broken (C1) |
| locked | other error | locked, `lastError` if any else generic | P2 broken (fixed with C1) |
| locked, restore found nothing | purchase or approval lands | unlocked, red "No purchase found" stays | P4 broken (M1) |
| pending | delegate delivers entitlement | unlocked, open paywall closes | P1 |

### SM3. Star prompt (`ReviewPromptTracker`, `RootTabView`)

State in UserDefaults: launch count, first open, last shown, outcome, positive-moment count and ids, pending flag, soft-defer flag, distinct use days. Trigger: opening a personal-best race posted a notification that `RootTabView` turned into `requestReview()` with no delay and no check for a presented sheet. Rewritten by Rollout S; see `rollout-2026-11-24.md`.

### SM4. Race notes (`RaceNotesStore`, `RaceNoteEditor`)

Save writes the whole note; an emptied note deletes the entry; Cancel with changes asks to discard; swipe-down is blocked while dirty; Delete writes an empty note. No partial-restore path. No bug found.

### SM5. Pattie Mode, feed config, episode cache

`PattieMode.isEnabled` persists and turning it off dismisses the popup and stops the voice (`PattieMode.swift:146-151`). The feed config and the Pointers and Ask Pattie catalogs are cache-plus-timestamp with cancellation already covered by `CancelledFetchTests`. Clearing downloaded episodes only deletes cache files. No bug found.
