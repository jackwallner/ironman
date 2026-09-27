# IM Iron Splits: Project Guide

Your triathlon and running race results, pulled from the official timing feed by
name, ranked by split. XcodeGen project/scheme: `IronSplits`, sim lease owner
`ironsplits`. Repo dir stays `~/ironman` (the GitHub Pages URL that
`FeedConfig` hot-reloads from lives there), but the app is **IM Iron Splits**
and is never called IRONMAN: that is a registered trademark of the World
Triathlon Corporation. Jack chose the current name on 2026-08-20 over a flagged
objection that an IRON- lead morpheme in the same goods class carries real
App Review 5.2.1 and takedown risk. That call is his and is settled: do not
relitigate it. Never add a WTC logo, M-DOT, `140.6`/`70.3` as branding, or any
claim of affiliation, and keep the not-affiliated disclaimer in Settings.

## Design system
`DESIGN.md` is the design contract for this repo: tokens, the 4pt spacing scale,
the two radii, haptics, 44pt tap targets, and the light/dark rule. **Read it
before any UI change and follow it.** Every colour resolves through
`adaptive(light:dark:)` in `TriDesign.swift` because SwiftUI's `colorScheme`
does not reach UIKit-backed chrome; a literal `Color(red:...)` in a view is a
dark-mode bug waiting to happen. Never hardcode a colour, a padding, or a corner
radius in a view.

## Tech Stack
- Swift 6 / SwiftUI (strict concurrency), iOS 17+
- XcodeGen (`project.yml`). Targets: `IronSplits`, `IronSplitsTests`, `IronSplitsUITests`
- RevenueCat, entitlement `pro` (display entitlement `Iron Splits+`)
- No backend, no accounts, no user data leaves the phone

## Targets / bundle IDs
- `IronSplits`: `com.jackwallner.ironman`
- IAPs: `…ironman.pro` (lifetime), `…pro.yearly`, `…pro.monthly`

## The results feed (read this before touching `Shared/Services/`)

There is no public IRONMAN results API. `api.competitor.com` is gated behind an
Azure subscription key we do not have. What exists is the results site's own
proxy, which signs an arbitrary upstream OData URL server-side:

```
GET https://labs-v2.competitor.com/api/results-proxy?url=<encoded upstream>&pageSize=500
     upstream = https://api.competitor.com/web/results?$filter=…&$expand=…&$orderby=…
```

It accepts arbitrary `$filter`, which is what makes the whole app possible: one
query on `wtc_ContactId/contactid` returns an athlete's entire career (IRONMAN,
70.3, Rock 'n' Roll marathons, trail races) with swim/T1/bike/T2/run/finish in
seconds, overall and division ranks per leg, bib, age group, and DNF/DNS/DQ
flags, back to 2002.

Four things that have already cost time:

- **`contains()` upstream is a full table scan and takes about thirty seconds.**
  The same two-word name written with `startswith()` comes back in about one and
  a half. That single operator was the whole "app is really slow to load"
  complaint, since search is the onboarding screen. `SearchDepth.prefix` is the
  default and runs on every keystroke; `.substring` is the `contains` fallback
  and only runs after the prefix pass returns nothing, with the UI saying so.
  Do not switch the default back.

- **`$expand` replaces the server's default expansion, it does not add to it.**
  Expanding only `wtc_EventId` silently drops `wtc_ContactId` from every row, so
  search returns 200 with rows that have no athlete on them. `ResultsAPI.expandClause`
  lists every relation the decoder reads; a test pins it.
- **Numbers arrive as both `3` and `"4"`,** and bibs as `"1,009"`. Everything
  decodes through `LooseInt` / `LooseDouble`. A strict decode drops whole pages.
- **`0` is the feed's "no data"** for a leg that never happened. A DNF carries a
  0 run split, so zeros become nil in `ODataResultRow.positive(_:)` or DNFs win
  every leaderboard.

The proxy is somebody else's service and can change without warning. Every part
of the request lives in `FeedConfig`, which the app re-reads from
`docs/api-config.json` on this repo's GitHub Pages every six hours. **If the feed
moves, publish a new `api-config.json`, do not ship an app update.**

## Architecture
- `Shared/Models/`: `RaceResult` (+ `Discipline`, `RaceKind`), `Athlete`, `Pointer`,
  `AskPattieGuide`
- `Shared/Services/`: `ResultsAPI` + `ODataResultRow` (feed), `FeedConfig`/`FeedConfigLoader`
  (hotfix channel), `LockerStore` (claimed athlete + on-disk cache), `RaceAnalytics`
  (every derived number), `ProGate`, `RaceNotesStore`, `ResumeBuilder`, `StoreService`,
  `PattieMode`, `PattieVoice`, `PointerMediaCache`
- `IronSplits/Views/`: five tabs: Locker, Bests, Pattie, Resume, Settings.
  The Pattie tab holds both `AskPattieView` and `PointerLibraryView` behind a
  nav-bar segmented control, which is what keeps the tab bar at five.

Ranking is always scoped to one `RaceKind`. A 70.3 bike split always beats a
full-distance one, so a combined "best bike" list is just a list of every half
the athlete has done.

## Free vs Pro: only Race Book is gated
`ProGate` is the **single** switch and `ProGate.everythingUnlocked` is `false`.
The complete locker, splits, rankings, field context, notes and race details
are free for everyone; the one paid boundary is Race Book, meaning
like-for-like race comparison and unlimited PDF/image export. Gate any new
feature through `ProGate`, never through a fresh entitlement check.

**Never ship a build with the paid boundary open.** 1.0 build 13 archived with
a `RACE_BOOK_TEST_UNLOCK` compile condition in the Release config, so App
Review saw "Race Book is unlocked" next to Restore purchases and an IAP that
had never been submitted, and rejected it under Guideline 2.1(b) on
2026-09-06. Both the condition and the `#if` in `ProGate` are gone. To open the
gate for local work, use `IRONSPLITS_FORCE_PRO=1` on the Debug scheme, which
cannot reach Release.

The one paid product is `com.jackwallner.ironman.pro`, a non-consumable
lifetime unlock. `…pro.yearly` / `…pro.monthly` exist only as identifiers
`StoreService` still recognises on a receipt; they have never existed in App
Store Connect and are not sold. Say nothing in user-facing or reviewer-facing
copy about "existing Iron Splits+ customers": the app has never shipped, so a
prior purchase reads to App Review as content sold outside the App Store.
Restore Purchases still stays visible, because a buyer needs it on a new
device.

## App-specific notes
- **Pointers, Ask Pattie and Pattie's voice clips are hosted or generated content.** Regenerate `docs/ask-pattie.json` with `scripts/build-ask-pattie.py` rather than hand-editing it, and nothing of Pattie's voice is ever synthesised. Details (media hosting, why episodes are cached rather than streamed, clip cutting) are in `.claude/rules/pointers-and-pattie.md`, which loads when you read a matching file; AGENTS.md readers should open it directly.
- Review funnel trigger: opening a race detail (`RaceDetailView.task`). The ASC
  record is `6803727074`, and `AppStoreReviewLinks` is configured so Settings
  can show the native rating entry.
- `IronSplitsSecrets.revenueCatKey` holds the production public SDK key
  (`appl_…`), set 2026-08-20. Only public keys go in that file; the RevenueCat
  **secret** key (`sk_…`, full REST access) lives in `~/.ironsplits_credentials`
  and must never enter the repo, the binary, or `docs/` (public Pages).
- Bundle ID is `com.jackwallner.ironman`, matching the RevenueCat dashboard
  app. Jack chose this deliberately on 2026-08-20 after the trademark risk was
  raised; settled, do not relitigate.
- UI tests hit the live feed on purpose. The claim flow is a search against
  someone else's service and a mock would only prove the mock still matches.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, review funnel, gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill.
