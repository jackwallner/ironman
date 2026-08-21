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

## Free vs Pro: currently nothing is gated
`ProGate.everythingUnlocked` is `true`, and it is the **single** switch. Every
gate in the app reads it (`StoreService.isPro` returns true while it is set, and
`apply(customerInfo:)` refuses to close a door it opened). No screen draws a lock
and `PaywallView` is not presented from anywhere.

Nothing was deleted, so flipping the flag restores the whole thing: `LockedRow`,
the three-race free window (over the whole history, not per filter, see
`LockerView.visibleResults`), and the paywall triggers. If you add a new
feature, gate it through `ProGate`, never through a fresh entitlement check.

Restore Purchases stays visible regardless: people who already bought Iron
Splits+ still need to reattach a receipt on a new device.

## App-specific notes
- **Pointers content is not in the app.** The catalog is fetched from
  `docs/pointers.json`; `docs/POINTERS.md` documents the schema and hosting.
- **The episodes cannot be streamed from where they are hosted, and this is not
  a bug in the player.** A GitHub release asset is served as
  `application/octet-stream` with `Content-Disposition: attachment`, after a
  redirect to a signed URL with no file extension in its path. `AVURLAsset`
  needs either the MIME type or the extension and that response gives it
  neither, so `VideoPlayer` showed a black rectangle. `PointerMediaCache`
  downloads to a local `.mp4` first, which also makes replays instant and works
  offline. If the media ever moves to a host that sends `video/mp4`, streaming
  would work again and the cache could go.
- **The hosted episode files are 426x240.** They will look soft full-screen on a
  phone. Re-encoding from higher-resolution originals (which are not in this
  repo) is worth doing before any App Store screenshot features the player.
- **Ask Pattie is a deterministic tree, not a chat.** `docs/ask-pattie.json`
  holds goals, topics and answers; the app bundles a copy as the offline
  fallback and hot-loads the hosted one. It costs nothing per question, can only
  surface advice Pattie actually gave on camera, and works with no signal.
  `scripts/build-ask-pattie.py` regenerates it and **refuses to publish a tree
  with a dead end**, so run it rather than hand-editing the JSON.
- **Pattie's voice clips are cut from her own episodes** by
  `scripts/cut-pattie-voice.py`, using Whisper word timestamps snapped to the
  nearest real silence. There are 56 in `IronSplits/Resources/PattieVoice/`:
  18 sign-offs, 19 situation hooks, 19 solutions. Nothing is synthesised, and
  nothing should be.
- Review funnel trigger: opening a race detail (`RaceDetailView.task`). App Store
  ID is unset in `AppStoreReviewLinks` until the ASC record exists, which is what
  makes Settings show "Send feedback" instead of "Rate".
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

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.
