# Overnight findings, 2026-10-30

Bug hunt and release review of the IM Tri Tracker iOS app (`IronSplits`,
1.1.3 build 35, snapshot of `ec37e0b`). Report only: nothing was fixed, and
the scratch tests used as evidence were deleted afterwards.

How each finding was established:

- **Failing test**: a scratch XCTest that asserts the correct behaviour failed
  on gh-sim (GitHub Mac, Xcode 27.1, iPhone 17 simulator, iOS 27.0).
- **Runtime**: a scratch UI test on the same runner, with screenshots.
- **Live feed**: counted against the real results proxy on 2026-10-30.
- **Source only**: read from the code, not executed.

gh-sim runs: `41018819482` (unit tests), `41028728067` (UI tests),
RUN_UI_PLACEHOLDER, RUN_UNIT_PLACEHOLDER.

Already covered elsewhere and not repeated here: everything in
`project-docs/audits/` (audit823, caudit926, laudit926, uiaudit930, aso827),
`qa/ledger.jsonl`, and the open `qa/backlog.jsonl` rows (contrast, hit areas
on Terms, Privacy, Restore and Privacy details, Reduce Motion, the AX3
Settings label). Where a finding touches an earlier one, its section says how
it differs.

## Summary

| ID | Sev | Area | Finding | Established by |
|---|---|---|---|---|
| ON-01 | ON01_SEV | Race Book export | ON01_TITLE | ON01_BY |
| ON-02 | P1 | Locker | Opening Race Book switches the Locker from All to one distance | Runtime |
| ON-03 | P1 | Results | Bike DNFs are filed by the distance covered: shown as halves, or dropped | Failing test, live feed |
| ON-04 | P2 | Locker | Re-claiming the same athlete during a refresh leaves the Locker spinning | Failing test |
| ON-05 | P2 | Search | Same-name, same-gender strangers in one city merge into one athlete | ON05_BY |
| ON-06 | P2 | Persistence | One unreadable note erases every note on the next save | Failing test |
| ON-07 | P2 | Feed hotfix | `api-config.json` cannot repoint the feed to a new host | Source only |
| ON-08 | P2 | Tips | Ask Pattie hides "Full clip" until the episode library has been opened | Runtime |
| ON-09 | P2 | Analytics | A tied best leg is a PB in the Locker but not in the race detail | Failing test |
| ON-10 | P3 | Dates | A 1 January race files under the previous year west of UTC | ON10_BY |
| ON-11 | P3 | Paywall | A failed purchase shows a stale, unrelated store message | Source only |

ON01_SECTION

## ON-02 (P1) Opening Race Book switches the Locker from All to one distance

**Where.** `IronSplits/Views/RaceBookView.swift:616-625`: `syncKind()` picks
Race Book's default distance and line 624 writes it with
`settings.preferredKind = selectedKind`. It runs from `.onAppear` at `:52-55`,
and the Race Book distance chip writes the same key at `:281`. The Locker
re-reads that key on every appear: `IronSplits/Views/LockerView.swift:66`
calls `syncKindFilter()` (`:399-405`). One shared key:
`Shared/Services/AppSettings.swift:44-52`.

**Reproduction (runtime, run 41028728067).** Seeded athlete with four full
and three half finishes. Launch: the Locker shows All and lists the 2025
Lakeside Half Triathlon. Tap the Race Book tab, then the Locker tab. The
filter now reads Full distance and the half is gone. Pushing and popping a
race keeps it on Full. Screenshots `1-locker-before-race-book`,
`3-locker-after-race-book` and `3b-locker-after-race-detail` in that run.

**Impact.** Every multi-distance athlete who looks at Race Book (one of five
tabs) comes back to a Locker missing all of one distance without touching a
filter, under a header that still counts them. For an athlete with finishes
at only one distance the chips are hidden (`LockerView.swift:162`), so the
forced filter cannot be cleared from the Locker at all, and any DNF or DNS
at the other distance silently drops out of the list.

**Why.** Race Book has no All, so its "nothing chosen yet" resolves to the
most-raced distance, and `syncKind()` then stores that automatic default in
the preference the Locker treats as the athlete's last explicit choice. The
Locker's All (`nil`) never survives a visit. This came in with the follow-up
to laudit926 CX-019, which connected `preferredKind` to both screens.

**Smallest fix.** Delete line 624 so an automatic default is never persisted,
and give Race Book its own stored key (or have the Locker read
`preferredKind` only in Rankings mode) so a Race Book chip tap does not
filter the Locker either.

**Guard.** The UI test used here: launch seeded, open Race Book, return,
assert All is selected and the half row is listed.

## ON-03 (P1) Bike DNFs are filed by the distance covered: shown as halves, or dropped

**Where.** `Shared/Models/RaceResult.swift:233-249`: `RaceKind.init` trusts
`bikeDistanceKm` before anything else (`> 140` full, `> 60` half, otherwise
`otherTriathlon`). That value is `wtc_bikedistancecompleted`
(`Shared/Services/ODataResultRow.swift:108`), the distance the athlete
actually covered. Unsupported kinds are then removed at
`Shared/Services/ResultsAPI.swift:132` and `Shared/Services/LockerStore.swift:139`.

**Reproduction (failing tests, run 41018819482).**
- A 2025 IRONMAN Texas DNF row that stopped at 99.65 km on the bike
  classifies as `halfDistance` (expected `fullDistance`).
- A Texas DNF at 46.0 km and a 2026 IRONMAN 70.3 Northern California DNF at
  44.5 km classify as `otherTriathlon`.
- A Locker claimed with that early DNF plus one finish shows 1 race, not 2.

**Live feed, 2026-10-30.** 2025 IRONMAN Texas has 298 DNF rows: 33 stopped
between 60 and 140 km on the bike (shown as half-distance races) and 29
between 1 and 60 km (dropped). 2026 IRONMAN 70.3 Northern California has 100
DNF rows: 18 stopped between 1 and 60 km (dropped). Rows with no bike
distance fall through to the name check and are filed correctly.

**Impact.** A full-distance DNF on the bike is tagged HALF in the Locker,
listed under Half distance, and its race detail badge reads "Half
distance". An early-bike DNF disappears from the Locker, Explore and Race
Book, so STARTS and the DNF count are short and the athlete's record is
incomplete. Rankings are unaffected because DNFs are excluded. That is about
a fifth of all DNF rows at the two events counted.

**Why.** For a non-finisher, distance completed is a lower bound, but the
classifier reads it as the course length.

**Smallest fix.** Pass `isFinisher` (or `isComplete`) into `RaceKind.init`
from `RaceResult.kind` (`RaceResult.swift:67-73`). For a non-finisher, a
covered bike distance above 90.6 km proves a full; below that, use the name
check (`70.3`/`IM703` half, `IRONMAN` full) before any distance threshold.
Keep the implausible-speed halving for finishers only.

**Guard.** The three scratch tests, kept in `RaceAnalyticsTests` with the
live row shapes (partial `wtc_bikedistancecompleted`, `wtc_biketime` 0).

## ON-04 (P2) Re-claiming the same athlete during a refresh leaves the Locker spinning

**Where.** `Shared/Services/LockerStore.swift:65-72`: `claim` bumps
`refreshGeneration`, empties `results`, sets `.loading` and calls
`refresh(force: true)`. At `:119` that refresh returns at once because the
same contact ids are already in flight. When the in-flight response arrives,
`:137-138` discards it as stale.

**Reproduction (failing tests, run 41018819482).** With a refresh in flight:
(a) Locker > Change > choose the same athlete > Replace; or (b) Settings >
Remove my athlete, then claim the same athlete again. Both end with
`state == .loading` and 0 results.

**Impact.** "Pulling your results…" never resolves. Recovery is the ... menu
> Refresh results, or a relaunch. In case (b) `unclaim()` already deleted
`locker.json` and nothing is saved again, so a relaunch returns to
onboarding. The window is the length of one refresh request (the launch
refresh after 30 minutes, pull to refresh, or "Refresh results" in the
Locker menu or Settings): short on good signal, long on bad.

**Why.** The single-flight guard added for laudit926 CX-012 compares contact
ids only. `claim()` invalidates the in-flight request by bumping the
generation, then its own refresh is skipped as a duplicate of the request it
just invalidated.

**Smallest fix.** Record the generation that owns the in-flight request and
skip only when `refreshingContactIDs == contactIDs` and that generation is
still current. (Clearing `refreshingContactIDs` in `claim()` and
`addContact()` also works, at the cost of one duplicate request.)

**Guard.** The two scratch tests: a `LockerStore` over a `ResultsProviding`
stub that delays 700 ms.

ON05_SECTION

## ON-06 (P2) One unreadable note erases every note on the next save

**Where.** `Shared/Services/RaceNotesStore.swift:68-72` decodes the whole
`[String: RaceNote]` with one `try?` and silently keeps an empty dictionary
on failure. `:49-58` and `:74-77` then write that in-memory dictionary over
the file. `RaceNote` (`:8-14`) uses synthesized `Codable`, which ignores the
property defaults and throws `keyNotFound` for any missing field.

**Reproduction (failing test, run 41018819482).** A `race-notes.json` holding
two notes, one without `updatedAt`, loads 0 of 2. Saving a third note
rewrites the file with only the third.

**Impact.** Latent today, certain later. The first update that adds a field
to `RaceNote` makes every existing note undecodable: the athlete sees no
notes, and their first new note permanently deletes all the old ones. Notes
are local-only and cannot be fetched again. A corrupt file does the same
today.

**Why.** All-or-nothing decode followed by an unconditional overwrite.

**Smallest fix.** Give `RaceNote` an `init(from:)` that uses
`decodeIfPresent` with the current defaults, decode entries one at a time so
a bad one is skipped, and never overwrite a file that failed to decode (move
it aside as `race-notes.unreadable.json` first). `LockerStorage.load()`
(`Shared/Services/LockerStore.swift:188-191`) has the same pattern; there it
only costs a re-claim, because results can be fetched again.

**Guard.** The scratch test: two saved notes, one missing a field, both
survive a save.

## ON-07 (P2) `api-config.json` cannot repoint the feed to a new host

**Where.** `Shared/Services/ResultsFeed.swift:40-48`: `isValid` pins the
proxy to `labs-v2.competitor.com/api/results-proxy`, the upstream to
`api.competitor.com/web/results`, the referer host, and the parameter names
`url` and `pageSize`. `:72-78` pins every nextLink to `api.competitor.com`,
and `:150-151` ignores any config that fails `isValid`.

**Reproduction (source only).** Publish an `api-config.json` whose
`proxyURL` is `https://labs-v3.competitor.com/api/results-proxy`. Every
installed app rejects it in `refreshIfStale()` and keeps calling the old
host.

**Impact.** AGENTS.md says "If the feed moves, publish a new
`api-config.json`, do not ship an app update." Only `pageSize` and `maxPages`
can actually change. If the proxy's host, path or parameter name moves, the
case the channel exists for, search and refresh fail for every user until an
App Store update ships and is installed.

**Why.** The validation (in since 2026-08-22) stops a bad Pages deploy from
pointing the app somewhere unsafe, but it pins exact values instead of a
trusted domain.

**Smallest fix.** Accept any `https` host under `competitor.com` for both
URLs and the referer, allow the path and parameter names to change
(validated as plain tokens), and check nextLink hosts against `resultsURL`'s
host. If exact pinning is deliberate, correct the AGENTS.md promise instead.

**Guard.** `ResultsAPITests` cases: a `labs-v3.competitor.com` config is
valid, an `example.com` one is not.

## ON-08 (P2) Ask Pattie hides "Full clip" until the episode library has been opened

**Where.** `IronSplits/Views/AskPattieView.swift:255-258` fills the card's
catalog from `PointerLibrary.shared.catalog()`, which only returns memory or
the UserDefaults cache (`Shared/Models/Pointer.swift:76-84`). Only the
library screen (`IronSplits/Views/PointersView.swift:185-190`) and the Tips
pull to refresh (`:62-66`) fetch it. The button is drawn only when the
episode is found (`AskPattieView.swift:203-206`, `:233-247`).

**Reproduction (runtime, run 41028728067).** Fresh install, Tips > My first
triathlon > Race morning. Every answer names its episode, but each card
shows only "Hear it from Pattie" (`4-answers-fresh-install`).

**Impact.** The default Tips screen never offers the episodes to anyone who
has not opened All episodes or pulled to refresh. Once the catalog is cached
the button appears, so it reads as flaky rather than missing.

**Smallest fix.** `catalog = await PointerLibrary.shared.refresh()` in the
card's task (non-forced, so the 12 hour interval still applies), or warm the
catalog once in `AskPattieModel.load()`.

**Guard.** A UI test on a fresh install asserting `Full clip` on the first
answer card.

## ON-09 (P2) A tied best leg is a PB in the Locker but not in the race detail

**Where.** `Shared/Services/RaceAnalytics.swift:95-102`: `isPersonalBest`
is true only for `ranked.first`. It drives the race detail split markers
(`IronSplits/Views/RaceDetailView.swift:164-176`), Pattie's PB moment
(`:78-87`) and the review funnel (`Shared/Services/ReviewPromptTracker.swift:36`).
The Locker badges every tied race (`IronSplits/Views/LockerView.swift:385-397`),
and Rankings labels both "Personal best" (`:511`) while colouring only rank 1
(`:488`).

**Reproduction (failing test, run 41018819482).** Two full-distance races
with an identical 1:00:00 swim both have `gapToBest == 0`, but
`isPersonalBest` is true for one and false for the other.

**Impact.** Both Locker rows show "PB Swim"; the second race's detail shows
no PB marker, and Pattie and the review funnel treat it as an ordinary race.
Rare on swim, bike and run; likeliest on T1+T2, which is a few minutes in
whole seconds.

**Smallest fix.** Compare seconds, not identity: after the `count > 1`
guard, return `ranked.first?.seconds == seconds`, and colour the Rankings
number by `gapToBest == 0`.

**Guard.** The scratch test.

ON10_SECTION

## ON-11 (P3) A failed purchase shows a stale, unrelated store message

**Where.** `IronSplits/Views/PaywallView.swift:497-499` shows
`store.lastError` when `purchase` throws. `lastError` is only set by product
loading and the customer-info refresh (`Shared/Services/StoreService.swift:407`,
`:469`), never by `purchase(_:)`, so the real error is dropped. The empty
state at `PaywallView.swift:126` reads the same field.
`purchaseLifetimeDirect()` (`StoreService.swift:442-459`) repeats the pattern
and has no callers.

**Reproduction (source only).** Launch while the customer-info fetch fails
(sets "Couldn't refresh your Race Book purchase status…"), open the paywall
with cached plans, and have the purchase fail, for example with In-App
Purchases blocked in Screen Time. The sheet shows the refresh message, not
the purchase error.

**Smallest fix.** Show the thrown error's `localizedDescription` (RevenueCat
errors are written for users) and keep `lastError` for loading failures.

## Checked and fine

- **Paid boundary.** `ProGate.everythingUnlocked` is `false`; both overrides
  (`IRONSPLITS_FORCE_PRO`, `FORCE_PRO`) sit inside `#if DEBUG`; Release starts
  `isPro` at `false`. Compare and export are the only gated actions
  (`RaceBookView.swift:405-449`); everything else is free.
- **Entitlements.** Access resolves from `pro`, `Iron Splits+`, the legacy
  entitlement, ownership of the lifetime product, or a legacy subscription
  (`StoreService.swift:215-233`).
- **Offline paying user.** Setting `Purchases.shared.delegate` makes
  RevenueCat send its cached CustomerInfo (the SDK's delegate setter calls
  `sendCachedCustomerInfoToDelegateIfExists`), so Race Book stays unlocked
  with no network even though the `.fetchCurrent` refresh fails.
- **Cancel, Ask to Buy, restore.** An SK2 cancellation returns
  `userCancelled` without throwing (RevenueCat's `Result(value, error)` keeps
  the CustomerInfo) and is handled as `.cancelled`; pending shows an approval
  message; the paywall dismisses when `isPro` flips; restore reports "No Race
  Book purchase was found" when there is none.
- **Paywall disclosure.** Price, "One-time purchase. Lifetime access, no
  subscription.", Terms (Apple EULA), Privacy and Restore are all on the sheet.
- **RevenueCat on simulators.** `revenueCatDebugKey` is empty and
  `configureIfNeeded()` refuses any non-`test_` key on a simulator, so no
  simulator or gh-sim run can create a production customer.
- **Locker cache.** Writes are atomic, unsupported kinds are filtered on
  load, and `Athlete` decodes old caches that lack `contactIDs`.
- **Crash scan.** No `try!` or forced casts in app code. `years.min()!` is
  guarded by `isEmpty`; `races[1]` in `RaceBookAnalytics.comparisonPair` and
  `RaceCompareView.syncRaces` is guarded by `count >= 2`; the PDF chart's
  `pointsOnChart[0]` by `count > 1`; the `URL(string:)!` literals are
  constants.
- **Field context.** Rank and percentile are clamped, DNFs never show the
  field card, and an empty event id shows the unavailable state (laudit926
  CX-010 is fixed).
- **Dates.** Every label goes through `RaceDate` in UTC and the resume uses a
  UTC calendar; only `RaceResult.year` differs (ON-10).
- **Search and claim.** A new query clears the previous matches and every
  response is generation-checked (laudit926 CX-001 is fixed); a claim ignores
  double taps and replacing an athlete asks first.
- **Explore** never touches the Locker: it selects through `onSelect` and
  keeps its own read-only state.
- **Export.** The share image is a fixed 1080x1920 render built off the main
  actor, and a stale build is dropped by its generation number.
- **Feed decoding.** `LooseInt`, `LooseDouble`, `LooseBool`, the 0 and 99999
  sentinels and the full `$expand` clause match AGENTS.md and are pinned by
  tests.
- **Privacy manifest** declares UserDefaults (CA92.1) and file timestamps
  (C617.1); app code uses no other required-reason API (no disk space, boot
  time or keyboard APIs).
- **App Review.** No accounts, so no deletion requirement. Ask Pattie content
  makes no medical claims (no injury, doctor or treatment wording). The
  not-affiliated disclaimer is in Settings.
- **Accessibility beyond the backlog.** Icon-only toolbar controls carry
  labels ("Change athlete", "More locker actions", "Clear race search"), and
  the Pattie hero image is one labelled element.
