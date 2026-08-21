# IM Iron Splits — Project Guide

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

## Tech Stack
- Swift 6 / SwiftUI (strict concurrency), iOS 17+
- XcodeGen (`project.yml`). Targets: `IronSplits`, `IronSplitsTests`, `IronSplitsUITests`
- RevenueCat, entitlement `pro` (display entitlement `Iron Splits+`)
- No backend, no accounts, no user data leaves the phone

## Targets / bundle IDs
- `IronSplits` — `com.jackwallner.ironsplits`
- IAPs: `…ironsplits.pro` (lifetime), `…pro.yearly`, `…pro.monthly`

## The results feed (read this before touching `Shared/Services/`)

There is no public IRONMAN results API. `api.competitor.com` is gated behind an
Azure subscription key we do not have. What exists is the results site's own
proxy, which signs an arbitrary upstream OData URL server-side:

```
GET https://labs-v2.competitor.com/api/results-proxy?url=<encoded upstream>&pageSize=500
     upstream = https://api.competitor.com/web/results?$filter=…&$expand=…&$orderby=…
```

It accepts arbitrary `$filter`, which is what makes the whole app possible: one
query on `wtc_ContactId/contactid` returns an athlete's entire career — IRONMAN,
70.3, Rock 'n' Roll marathons, trail races — with swim/T1/bike/T2/run/finish in
seconds, overall and division ranks per leg, bib, age group, and DNF/DNS/DQ
flags, back to 2002.

Three things that have already cost time:

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
moves, publish a new `api-config.json` — do not ship an app update.**

## Architecture
- `Shared/Models/` — `RaceResult` (+ `Discipline`, `RaceKind`), `Athlete`, `Pointer`
- `Shared/Services/` — `ResultsAPI` + `ODataResultRow` (feed), `FeedConfig`/`FeedConfigLoader`
  (hotfix channel), `LockerStore` (claimed athlete + on-disk cache), `RaceAnalytics`
  (every derived number), `ProGate`, `RaceNotesStore`, `ResumeBuilder`, `StoreService`
- `IronSplits/Views/` — five tabs: Locker, Bests, Pointers, Resume, Settings

Ranking is always scoped to one `RaceKind`. A 70.3 bike split always beats a
full-distance one, so a combined "best bike" list is just a list of every half
the athlete has done.

## Free vs Pro
Free: search, claim, and the three most recent races with full splits. Pro: full
history, split leaderboards, field percentiles, race notes, resume export, and
the non-free Pointers episodes. The free window is over the whole history, not
per filter — see `LockerView.visibleResults`.

## App-specific notes
- **Pointers content is not in the app.** The catalog is fetched from
  `docs/pointers.json`; `docs/POINTERS.md` documents the schema and hosting. The
  21 Tri Patties Pointers clips still need to be encoded and hosted.
- Review funnel trigger: opening a race detail (`RaceDetailView.task`). App Store
  ID is unset in `AppStoreReviewLinks` until the ASC record exists, which is what
  makes Settings show "Send feedback" instead of "Rate".
- `IronSplitsSecrets.revenueCatKey` holds the production public SDK key
  (`appl_…`), set 2026-08-20. Only public keys go in that file; the RevenueCat
  **secret** key (`sk_…`, full REST access) lives in `~/.ironsplits_credentials`
  and must never enter the repo, the binary, or `docs/` (public Pages).
- The RevenueCat dashboard app is still registered as bundle ID
  `com.jackwallner.ironman`. Purchases will not validate until it is changed to
  `com.jackwallner.ironsplits`.
- UI tests hit the live feed on purpose. The claim flow is a search against
  someone else's service and a mock would only prove the mock still matches.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, review funnel, gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill.

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.
