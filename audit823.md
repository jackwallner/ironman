# IM Tri Tracker / IM Iron Splits audit823

Audit date: 2026-08-23

Scope: the local repository at `/Users/jackwallner/ironman`, its checked-in and
currently present local configuration, the ASC and RevenueCat identity evidence
available in the signed-in context, and the local production-adjacent web/legal
assets. This document is an audit only. No app code, configuration, metadata,
website, or operational system was changed by this audit.

## Executive verdict

The current active product identity is `IM Tri Tracker`, while the local
repository and many internal implementation names still use `Ironman`, `Iron
Splits`, or `ironman`. The live ASC record visible in context is `IM Tri Tracker`,
app ID `6803727074`, iOS version `1.0`, status `Waiting for Review`. The local
RevenueCat project identity reconciles to the `Ironman App` project with project
ID `projd27c8a1b`, app ID `appc01c87659d`, bundle ID
`com.jackwallner.ironman`, and lifetime product
`com.jackwallner.ironman.pro`.

The most important finding is a release gating failure: Release builds currently
include `RACE_BOOK_TEST_UNLOCK`, and `ProGate.everythingUnlocked` consequently
returns true. If the ASC/TestFlight build under review was produced from this
configuration, the paid Race Book boundary is bypassed for every user. This is a
release and revenue blocker, not a cosmetic issue.

The second important finding is release artifact drift. The ASC screenshot
capture configuration expects eight raw captures including `bests.png`, while
the current dirty capture UI test produces seven and the current submission
folder has seven screenshots. A checked-in eight-image capture report is from an
older commit. This creates a high probability of submitting stale or
inconsistent screenshots.

The product currently has no active trial path. It exposes one non-consumable,
one-time lifetime purchase only. The code contains subscription and intro-offer
scaffolding, but `StoreService` filters the active offering to lifetime only and
the StoreKit configuration has no subscription group or intro offer. If the
business goal is trial starts, a real subscription/trial decision is still
required. If the business goal is the current one-time Race Book purchase, the
trial scaffolding should be removed or clearly isolated from active behavior.

Activation is promising but fragile. The first-run path requires a user to know
the exact name used by the race-results provider, then depends on a remote
results proxy and a potentially slow substring search. There is no remote
activation funnel, purchase funnel, or crash/UX watchdog instrumentation in the
local code. The app handles several failures locally, but there is no reliable
way to know from this repository whether a release caused a crash spike, a feed
outage, a paywall product-loading failure, or a regression in trial or purchase
conversion.

## Evidence conventions and limitations

Use the following labels throughout this report:

- **Confirmed local** means directly supported by files in the repository as it
  existed during this audit.
- **Context evidence** means supported by the signed-in ASC or RevenueCat
  context visible during the audit, not by a local export in this repository.
- **Inference** means a likely interpretation that must be validated against a
  live binary, ASC, RevenueCat, or production telemetry.
- **Gap** means the repository or available context does not contain enough
  evidence to answer the question.

No public rating count, review count, revenue total, trial-start count, crash
rate, or purchase conversion rate was fabricated. The ASC record was visible as
`Waiting for Review`, and the local sync state has no live version. A fresh ASC
Analytics export and a RevenueCat dashboard/API export are required for numeric
baselines after release.

The working tree was already dirty before this audit. It contains source and
test modifications, deleted Pattie image assets, and an untracked
`IronSplits/Views/RaceBookPDFPreview.swift`. The audit therefore describes both
repository intent and current files, but it does not claim that the current
tree is a reproducible release candidate. No build or test was run because the
request was limited to writing this audit file and no other file.

## Priority summary

| ID | Priority | Area | Finding | Evidence | Immediate decision |
| --- | --- | --- | --- | --- | --- |
| REL-001 | P0 | Entitlement/revenue | Release compilation enables the test unlock for all users. | `project.yml:39-42`, `IronSplits/Services/ProGate.swift:12-18`, `scripts/testflight.sh:30` | Remove the Release condition before any paid production build. Add a release assertion. |
| REL-002 | P0 | ASC assets | Capture config expects `bests.png`, current capture test produces seven images, and the checked-in eight-image report is from an older commit. | `fastlane/asc-screenshots.json`, `scripts/capture-asc-screenshots.sh`, `IronSplitsUITests/ASCReleaseCaptureUITests.swift`, `fastlane/asc-capture/race-book/capture-report.json` | Reconcile the current four-tab UI, capture test, raw assets, rendered assets, and ASC upload set. |
| REL-003 | P1 | Release provenance | TestFlight script archives Release and mutates the project version without guarding against a dirty tree or test unlock. | `scripts/testflight.sh` | Add preflight checks and fail closed on unsafe Release settings. |
| ID-001 | P1 | Naming | Active ASC/site/metadata brand is `IM Tri Tracker`, but internal docs, backups, product fallback names, and repository names retain legacy `Iron Splits` or `Ironman` naming. | `CLAUDE.md`, `README.md`, `fastlane/metadata.bak.*`, `StoreService.swift`, `project.yml` | Define canonical product, repository, bundle, and compatibility names. Label legacy names explicitly. |
| ID-002 | P1 | Agent docs | `CLAUDE.md` has stale tab and gating instructions and there is no clear repo-level AGENTS/Cursor/Codex map. | `CLAUDE.md:82-102`, repository file inventory | Refresh the canonical guide and add a small agent-doc index in a later implementation task. |
| FUN-001 | P1 | Trial/purchase | There is no active trial. The only live product model in local code is a lifetime non-consumable. | `IronSplits/Services/StoreService.swift`, `IronSplits/Services/PlanOption.swift`, `IronSplits/Services/Products.storekit` | Decide lifetime-only versus an actual subscription/trial model before optimizing trial starts. |
| FUN-002 | P1 | Measurement | No RevenueCat custom attributes, customer events, funnel counters, crash reporter, MetricKit, or remote UX telemetry were found. | Repository-wide search for `setAttributes`, `logEvent`, MetricKit, crash SDKs | Add a privacy-conscious, bucketed activation and purchase funnel. |
| FUN-003 | P1 | Review funnel | Every race detail appearance records a positive moment before checking whether the result is complete, and repeated appearances can count repeatedly. | `IronSplits/Views/RaceDetailView.swift:49-54`, `ReviewPromptTracker.swift` | Record a positive moment only after a qualifying complete result and deduplicate by race. |
| UX-001 | P1 | Activation | First run requires exact provider registration name and relies on a remote feed. Slow substring fallback can take about 30 seconds. | `AthleteSearchView.swift`, `ResultsAPI.swift`, `ResultsFeed.swift`, `docs/api-config.json` | Add sample/help paths, explicit timeout/retry states, and activation telemetry. |
| WEB-001 | P1 | Marketing consistency | ASC metadata uses the GitHub Pages URL while the site canonical tag uses `https://jackwallner.com/ios/ironman/`. | `fastlane/metadata/*/marketing_url.txt`, `scripts/generate-asc-metadata.py`, `docs/index.html:8` | Pick one canonical landing URL and verify redirects, metadata, legal links, and analytics. |
| RC-001 | P1 | RevenueCat | Local identity and product reconcile, but active offering/entitlement attachment and live metrics were not independently exported in this audit. | `scripts/rc-setup-race-book.py`, `StoreService.swift`, RC context | Add a read-only configuration check and export baseline metrics before changing paywall behavior. |
| UX-002 | P2 | Paywall | Native SwiftUI paywall is custom and only shows lifetime; trial/monthly/yearly branches are inactive scaffolding. | `PaywallView.swift`, `StoreService.swift`, `PaywallScreenshotMode.swift` | Optimize the active lifetime flow, or implement a deliberate trial model rather than testing dead branches. |
| WEB-002 | P2 | Legal | Terms and privacy are broadly aligned with the lifetime-only product, but legacy subscription text can confuse a new buyer. | `docs/terms.html`, `docs/privacy-policy.html`, `docs/support.html` | Keep legacy language if needed, but label it as compatibility language and review on any pricing change. |
| OPS-001 | P2 | Watchdog | Local error handling exists, but no live alert pipeline can identify a crash spike or remote feed regression. | `ResultsAPI.swift`, `ResultsFeed.swift`, `StoreService.swift`, repository-wide SDK search | Add ASC/MetricKit and service/paywall health checks with release baselines. |

## Identity reconciliation

| Layer | Current identity | Evidence | Confidence and implication |
| --- | --- | --- | --- |
| Local repository directory | `/Users/jackwallner/ironman` | Filesystem path and git repository | Confirmed local. Repository slug is a legacy implementation name. |
| Internal project guide | `IM Iron Splits` | `CLAUDE.md` title | Confirmed local. This is not the current public store display name. |
| README product heading | `IM Tri Tracker` | `README.md:1` | Confirmed local. |
| Xcode product name | `IM Tri Tracker` | `project.yml:28`, generated project settings | Confirmed local. |
| Installed display name | `IM Tri Tracker` | `IronSplits/Info.plist:8` | Confirmed local. |
| Bundle ID | `com.jackwallner.ironman` | `project.yml`, `Info.plist`, RC setup script | Confirmed local. Do not change casually because it is the store and purchase identity. |
| ASC application | `IM Tri Tracker` | ASC context, app ID `6803727074` | Context evidence. Status shown as iOS `1.0`, `Waiting for Review`. |
| App-review link ID | `6803727074` | `IronSplits/Services/AppStoreReviewLinks.swift:6` | Confirmed local and reconciled to ASC context. |
| RevenueCat project | `Ironman App`, project `projd27c8a1b` | `scripts/rc-setup-race-book.py:20-27`, RC context | Confirmed local plus context evidence. Project display name is legacy but project identity matches. |
| RevenueCat app | `appc01c87659` | `scripts/rc-setup-race-book.py:20-27` | Confirmed local. |
| RevenueCat product | `com.jackwallner.ironman.pro` | `StoreService.swift`, `Products.storekit`, RC setup script | Confirmed local. |
| RevenueCat package | `$rc_lifetime` | `scripts/rc-setup-race-book.py`, `StoreService.swift` package filtering | Confirmed local. |
| RevenueCat entitlement | Primary `pro`, fallbacks `Iron Splits+` and `Ironman App Pro` | `RevenueCatConfig` in `StoreService.swift` | Confirmed local. Attachment of every fallback is not confirmed. |
| Public marketing brand | `IM Tri Tracker` | `docs/index.html`, active fastlane metadata | Confirmed local. |
| Legacy compatibility names | `IM Iron Splits`, `Iron Splits+`, `Ironman App Pro`, `Ironman` | source, docs, RC config, bundle ID | Confirmed local. These must be labeled as legacy/internal so agents do not reintroduce them into public copy. |

### Naming conclusion

The bundle ID and repository slug can remain legacy identifiers. The public
brand, ASC name, display name, metadata, site, paywall, and legal documents
should remain `IM Tri Tracker` unless a separate rebrand is intentionally
approved. The RevenueCat project and entitlement aliases should be treated as
compatibility identifiers. They should not be used as new public-facing copy.

`README.md` includes an ASC checklist label `IM Tri Tracker: Race Results`,
while the visible ASC app list showed `IM Tri Tracker`. The colon suffix is
probably an old internal label, but it should not be presented as the current
ASC record name without verification.

## Release and repository state

### Current local state

- Branch: `main`.
- Current HEAD: `e614671`, commit subject `chore: bump build number to 14`.
- The worktree was already dirty with source, test, shared service, asset, and
  untracked preview changes.
- The audit did not stage, revert, clean, generate, build, test, commit, or push.

The dirty tree matters because the checked-in screenshot capture report points
to commit `5326b1bea66fc3a36cb39244f6726bcc173683f3`, not the current HEAD. A
release handoff should state exactly which commit produced the archive,
screenshots, metadata, and website deployment.

### Build configuration findings

`project.yml:39-42` adds `RACE_BOOK_TEST_UNLOCK` to the Release compilation
conditions. `IronSplits/Services/ProGate.swift:12-18` makes
`everythingUnlocked` true whenever that condition is present. The same setting
is present in the generated Xcode project at the Release configuration.

`StoreService.isPro` also starts from `ProGate.everythingUnlocked`, so the
compile-time flag affects both UI gating and purchase state. In
`StoreService.apply`, entitlement processing returns early when the test unlock
is active. This means a successful real purchase is not the only path to the
unlocked state in a Release build.

`scripts/testflight.sh` archives with `-configuration Release`. Therefore:

1. The local release path is explicitly wired to the unsafe configuration.
2. If build 14 or the ASC review build came from this path, Race Book compare
   and export may be available without purchase.
3. RevenueCat product availability and entitlement correctness could be hidden
   during review because the UI already believes the user is Pro.
4. Any local conversion result from that build would not represent the intended
   purchase funnel.

This conclusion is **confirmed local** for the current source configuration and
an **inference** about the binary already submitted. Inspect the archived
binary's build settings or compiled symbols before making a final ASC release
decision.

### Release gate to add later

The release process should fail before archive if any of the following is true:

- Release settings contain `RACE_BOOK_TEST_UNLOCK`.
- A Release binary contains the test unlock condition or test-only unlock code.
- The app is pointed at a production RevenueCat key in a simulator build.
- The configured bundle ID, ASC app ID, product ID, and app display name do not
  match the release manifest.
- The repository has uncommitted changes, unless an explicit release override is
  supplied and recorded.
- The screenshot manifest does not match the current capture test and upload
  folder.
- The generated project differs from `project.yml` after XcodeGen.

## Product flow map

The current intended user journey is:

```text
Fresh launch
  -> RootTabView checks for a saved athlete
  -> AthleteSearchView onboarding
  -> quick prefix search, then optional slow substring search
  -> user claims one result
  -> LockerStore persists the athlete and loads locker.json
  -> Locker list shows races and the Race Book cross-sell
  -> RaceDetailView loads split/rank data and the full event field
  -> user opens Race Book
  -> Race Book preview shows history, bests, progression, compare, and export
  -> compare or export can present PaywallView
  -> custom SwiftUI paywall loads the RevenueCat lifetime package
  -> purchase or restore updates the `pro` entitlement
  -> Race Book compare/export unlocks
```

Important branches:

- A feed config is refreshed from GitHub Pages and can change the results proxy
  without an app update.
- Prefix search is fast; substring search is intentionally slower.
- Locker data is cached in Application Support and refreshes after its cache
  interval or a manual refresh.
- Full race field data is loaded separately from the athlete's own result.
- Notes are local and can be included in exports.
- Pointer media is downloaded from a GitHub release and cached locally.
- Review eligibility is tracked locally in UserDefaults.
- Purchase state is fetched and restored through RevenueCat.

## ASC metadata and store conversion

### Current metadata inventory

The local `fastlane/metadata` tree contains 51 locale directories. The standard
metadata fields are present across the active locales, including name, subtitle,
keywords, description, promotional text, support URL, marketing URL, privacy
URL, and release notes. The English active values are:

- Name: `IM Tri Tracker`.
- Subtitle: `Your race splits, ranked`.
- Keywords: `triathlon,race results,splits,swim,bike,run,bib,finish,personal best,race history,rankings`.
- Marketing, support, and privacy URLs point to the GitHub Pages site and its
  legal routes.
- Description positions the product as a race-results and split-ranking tool,
  describes field rank and percentiles, offers Race Book as a one-time lifetime
  purchase, and says there is no subscription.
- Promotional text and release notes use the active product name.

The metadata copy is broadly aligned with the active app UI, website, terms,
privacy policy, and paywall. In particular, the one-time/no-subscription claim
is repeated consistently in current public-facing files. That is a strength.

### Metadata risks

1. `scripts/generate-asc-metadata.py` has current and legacy brand constants and
   keeps the source translation templates under the old `IM Iron Splits` name.
   `write_metadata` replaces the legacy name with `IM Tri Tracker` when writing
   output. This currently produces the desired files, but a future agent editing
   a template may not realize that the transformation is required. Make the
   public brand a single explicit placeholder and test that no legacy public
   brand remains in generated output.
2. `fastlane/metadata.bak.20260822-182631` includes the old public name
   `IM Iron Splits: Race Results`. `fastlane/metadata.bak.20260823-004035` is a
   newer backup. These directories can be accidentally selected by a script or
   edited by an agent. They should be moved to a clearly labeled archive or
   ignored by upload tooling in a separate cleanup change. Do not delete them
   without confirming they are recoverable.
3. The English name is short and understandable, but `IM` is not self-explanatory
   to a new store visitor. Test whether the subtitle and first screenshot make
   the product category obvious without relying on the legacy name.
4. Keywords are descriptive but may be too broad. The list should be evaluated
   against ASC Search Ads or approved keyword tooling, not intuition. Preserve
   exact-result intent terms such as race results, splits, rankings, and personal
   bests if they produce qualified traffic. Avoid trademark terms that are not
   safe or authorized for public acquisition.
5. The metadata uses many locales, but no locale-level impression, conversion,
   or search-rank evidence is stored locally. A translation existing is not
   evidence that it is useful. Measure by storefront rather than assuming all
   51 locales are equally valuable.

### Metadata experiments

Run one controlled store experiment at a time, with a fixed date range and the
same app version where possible. Suggested hypotheses:

| Experiment | Variant A | Variant B | Primary metric | Guardrail |
| --- | --- | --- | --- | --- |
| Positioning | `Your race splits, ranked` | A result-history or race-book benefit subtitle | Product-page conversion rate | Search impressions and qualified download rate |
| Search intent | Split/ranking keyword mix | Race-history/personal-best keyword mix | Product-page views to downloads | Relevance, support requests, uninstall proxy |
| Screenshot order | Locker and ranking proof first | Race Book story and compare proof first | Download conversion | First-launch activation and paywall dismissal |
| Audience page | General race results story | Personal-best and progression story | Custom product page conversion | Activation to first claimed result |
| Price framing | Lifetime benefit in description and screenshot | Free core plus explicit unlock boundary | Purchase starts per activated user | Refunds, restore failures, support contacts |

For custom product pages, test at least these intent groups if ASC supports the
traffic split:

- race results and split rankings,
- personal bests and progression,
- field rank and comparison,
- race history and export/storytelling.

Do not claim an ASO win until ASC impressions, product-page views, downloads,
and downstream activation are joined by storefront and acquisition source. A
download without a claimed result is not a successful activation for this app.

### Metadata validation checklist

Before upload, validate in a disposable worktree or a generated-output staging
directory:

1. Every intended locale has a current brand name and no accidental
   `IM Iron Splits` public name.
2. Description, promotional text, screenshot copy, site title, paywall title,
   terms, and privacy policy describe the same product model.
3. Product claims are supported by the current binary. Do not advertise a
   trial, subscription, monthly plan, or yearly plan while the binary exposes
   only lifetime.
4. Marketing, support, privacy, and terms URLs resolve and use one canonical
   public host.
5. The app ID in store links is `6803727074`.
6. The screenshot set describes the current four-tab product, not an old Bests
   tab or old branding.
7. Release notes describe the build being submitted, not a stale backup.

## ASC screenshot and visual funnel audit

`fastlane/asc-screenshots.json` configures the app as `iron-splits`, display name
`IM Tri Tracker`, and expects eight captures: `locker`, `race-detail`, `bests`,
`race-book`, `race-book-compare`, `race-book-export`, `pattie`, and `settings`.
`scripts/capture-asc-screenshots.sh` uses the same attachment list.

The current dirty `IronSplitsUITests/ASCReleaseCaptureUITests.swift` captures
seven screens: locker, race detail, Race Book, Race Book compare, Race Book
export, Pattie, and Settings. It does not capture `bests.png`.

The current `fastlane/screenshots/en-US` directory also contains seven
submission PNGs, with names such as `01-turn-history-into-a-story` through
`07-learn-from-every-race-day`. The checked-in capture report under
`fastlane/asc-capture/race-book/capture-report.json` contains eight records,
including `bests.png`, and records an older commit. The rendered audit and
render report therefore prove only that an older eight-image set passed, not
that the current UI and current source produce that set.

This is a concrete pipeline mismatch. It can cause:

- a capture script failure because the expected attachment is absent,
- stale Bests-tab imagery being uploaded for a product whose root navigation no
  longer exposes that tab,
- screenshot order and feature claims to disagree with the current binary,
- an agent to infer that Bests is a top-level feature when it is now embedded in
  Race Book.

Resolve this by choosing one of two explicit product decisions:

1. Keep Bests as a standalone store story, restore or expose the intended
   destination, and capture it from the current binary.
2. Treat Bests as a Race Book section, remove `bests.png` from the capture
   manifest, and replace it with a current Race Book value moment.

Do not repair this by copying the old image into the seven-image folder. The
capture source, manifest, raw images, rendered images, and ASC upload list must
come from the same commit.

### Store screenshot UX opportunities

- First image: show the core free value and a recognizable result, not only a
  branded landing card.
- Second image: show rank or percentile with enough context to understand the
  result without opening the app.
- Race Book image: explain that the preview is free and compare/export are the
  lifetime unlock, avoiding an implied subscription.
- Compare image: show the decision or insight a user gets from comparing races,
  not just a screen title.
- Export image: show a finished artifact and where it can be shared.
- Pattie and pointers image: use these for differentiation only after the
  functional conversion story is clear.
- Settings image: keep only if it proves trust, privacy, or useful controls;
  otherwise it is a weaker acquisition frame than a completed result.

Validate every screenshot on the current headless simulator build, with no
production RevenueCat key. Confirm that text, safe areas, loading states, and
the paid boundary match the submitted binary.

## Onboarding, activation, and user experience

### What works well

- `RootTabView` routes a user without a saved athlete into
  `AthleteSearchView(isOnboarding: true)`, which reduces first-run navigation.
- The search UI distinguishes the fast prefix search from the slower full-index
  fallback rather than pretending both are equally fast.
- `LockerStore` persists the claimed athlete and cached `locker.json`, so a
  returning user can see prior data when the network is unavailable.
- A failed refresh with cached data remains useful and presents a warning rather
  than replacing usable data with a blank screen.
- `RaceDetailView` loads the full event field separately. A field failure does
  not need to block the user's own splits.
- The Race Book card in the locker creates a contextual upsell after a user has
  already seen the product's core value.
- The active paywall has a one-time-price disclosure, restore action, terms,
  privacy, loading state, and user-facing error state.

### Activation friction and fixes

#### Exact-name dependency

`AthleteSearchView` asks for the name as registered with the results provider.
Automatic search waits for three characters and debounces by about 400 ms;
manual submit accepts two characters. A user who does not know the exact
registration spelling may see no result even though the result exists.

Recommendations:

- Add a short example of the accepted name format.
- Add a “Try a sample result” path that does not claim or persist a real user.
- Add a support or “my result is missing” action directly from the no-results
  state.
- Preserve the entered query and let the user retry without losing onboarding
  context.
- Make the automatic and manual minimum-length behavior intentional and
  explain it in code comments or shared constants.
- Measure `search_started`, `quick_result`, `deep_search_started`,
  `no_results`, `result_claimed`, and `claim_failed`.

#### Slow substring fallback

`ResultsAPI` documents the prefix request as fast and the substring request as
slow. The UI warns that a whole-index search can take a while. The feed and
proxy configuration indicate a page size of 500 and up to 12 pages. A slow
fallback is acceptable only if it has a clear timeout and recovery path.

Recommendations:

- Show elapsed or stage state without implying the app is frozen.
- Provide Cancel and Retry actions.
- Use a bounded timeout with a support path rather than an indefinite spinner.
- Record latency buckets and provider HTTP/error classes locally or through a
  privacy-reviewed telemetry sink.
- Consider a server-side exact-name normalization or search endpoint so the
  client does not need to scan the full index.
- Add a cached sample/demo mode for users who want to understand the app before
  supplying their own name.

#### Claim versus first sync

The claim flow sets the selected athlete and then refreshes the locker. If the
initial feed refresh fails, a user can experience the result as a failed claim
even when the identity was stored successfully. Separate these states:

1. Identity selected and saved.
2. First result sync in progress.
3. First result sync succeeded.
4. Identity saved but sync failed, with retry and support options.

The success event for activation should be “first usable race loaded,” not just
the claim button tap.

#### Remote dependency resilience

`ResultsFeed` refreshes configuration from
`https://jackwallner.github.io/ironman/api-config.json`, caches it for roughly
six hours, validates it, and falls back when needed. The app then relies on the
configured results proxy. This is operationally flexible but creates two
runtime dependencies before a new user sees value.

Recommendations:

- Keep a last-known-good feed configuration with an explicit expiry policy.
- Add a local diagnostic state that distinguishes config failure, proxy failure,
  empty result, rate limiting, and invalid response.
- Add a user-facing retry that does not require leaving onboarding.
- Monitor first-load success by app version and feed-config revision.
- Treat changes to `docs/api-config.json` as production changes with a rollback
  path and a small canary check.

### Locker and race detail

`LockerStore` caches data in Application Support, refreshes after approximately
30 minutes unless forced, and uses a refresh generation to discard stale
responses. These are good consistency controls. Add visible last-updated time
and a clear distinction between cached and current data so a user does not
mistake stale results for a failed refresh.

`RaceDetailView` has explicit loading, loaded, and failed field states with a
retry. Keep split content usable when field data is unavailable. Instrument:

- own-result load success and failure,
- field load success and failure,
- response age,
- retry count,
- empty or incomplete result state,
- time to first meaningful result.

### Race Book UX and discoverability

The current working-tree version of `RaceBookView` combines the historical
resume, personal best, progression, compare, and export story. This is a
stronger unified product story than a collection of disconnected tabs, but it
creates two risks:

- a long scroll can hide the first reason to unlock,
- users may not understand which preview sections are free and which actions
  require the lifetime purchase.

Recommended tests:

- Put a contextual compare CTA immediately after the second comparable race,
  while retaining the full preview below it.
- Show one sample comparison result before the paywall, then gate the second
  comparison or export.
- Keep the locker Race Book card for discovery and test its copy against a
  concrete benefit such as “Compare your race-day decisions.”
- Test an early export preview versus an early comparison preview, but do not
  run both experiments at the same time.
- Make the locked state explain exactly what the lifetime purchase unlocks.
- Ensure the first paywall appears after a user understands the output, not on
  an unexplained tab entry.

The old `BestsView.swift` remains in the repository but is not routed by the
current `RootTabView`. This may be an intentional consolidation into Race Book,
but it is a source of stale screenshot and agent-documentation errors. Record
the decision and either remove or clearly mark the old view in a future cleanup.

### Pointer downloads

`PointerMediaCache.swift` downloads MP4 assets from GitHub releases, reports
progress, caches them locally, and supports clearing downloads from Settings.
This is a useful engagement feature but is not essential to first activation.

Monitor and improve:

- cache hit rate and time to first play,
- download failure and retry rate,
- cellular versus Wi-Fi behavior,
- free storage pressure and cache cleanup,
- asset version mismatch after a release,
- whether a pointer download blocks or distracts from the core result flow.

Do not make the first-run experience wait for pointer media.

## Trial, purchase, and RevenueCat audit

### Current product model

The active local product model is lifetime-only:

- `IronSplitsProduct.all` contains only `.lifetime`.
- The product ID is `com.jackwallner.ironman.pro`.
- `Products.storekit` defines one non-consumable product with display price
  `$9.99` and display name `Race Book`.
- There is no subscription group in the StoreKit configuration.
- There is no intro offer in the StoreKit configuration.
- `StoreService.fetchProducts` and `rebuildPlanOptions` filter to lifetime.
- The active paywall CTA is `Unlock Race Book` and the disclosure says it is a
  one-time purchase with no subscription.
- Intro-eligibility code exists, but no active subscription product reaches it.

Therefore the current app does not have a trial-start funnel. Trial starts are
not evidence of a broken conversion rate; they are not applicable under the
current product model. The code should not imply a trial simply because
`PaywallScreenshotMode` has `trial`, `monthly`, and `yearly` cases.

### Product decision required

Choose one model before adding funnel work:

#### Option A: lifetime-only Race Book

- Keep the one-time product.
- Remove or isolate inactive subscription/trial scaffolding.
- Optimize activated-user to purchase-start, purchase-success, restore-success,
  and retained-use metrics.
- Use “free core plus lifetime Race Book unlock” consistently.
- Do not report trial-start metrics for this product.

#### Option B: subscription with a real trial

- Define the subscription period, trial duration, price, eligibility, and
  entitlement behavior.
- Create the subscription group and introductory offer in ASC.
- Add the matching product and package to RevenueCat.
- Expose the package intentionally in `StoreService` and `PaywallView`.
- Explain billing timing, renewal, cancellation, restore, and trial conversion
  in paywall and legal copy.
- Add trial-start, trial-to-paid, cancellation, refund, and entitlement
  recovery measurements.
- Update website, support, terms, privacy, metadata, screenshots, and review
  notes together.

Do not A/B test an inactive trial branch. It will produce implementation noise
rather than a meaningful experiment.

### RevenueCat reconciliation

The local setup script `scripts/rc-setup-race-book.py` identifies:

- project ID `projd27c8a1b`,
- app ID `appc01c87659`,
- bundle ID `com.jackwallner.ironman`,
- product ID `com.jackwallner.ironman.pro`,
- product display name `Race Book`,
- lifetime package `$rc_lifetime`,
- primary entitlement lookup `pro`,
- legacy entitlement display aliases `Iron Splits+` and `Ironman App Pro`.

This matches the RevenueCat project list context showing `Ironman App` with the
same project suffix. Identity reconciliation is strong. It does not prove that
the current dashboard has the desired offering, product attachment, price, or
entitlement state. The setup script is mutating and should not be used as a
read-only audit command.

Specific verification still needed in RevenueCat:

1. The `com.jackwallner.ironman.pro` product is attached to the intended
   lifetime package in the current public offering.
2. The lifetime package is attached to the intended `pro` entitlement.
3. Any fallback aliases are intentionally present or intentionally retired.
4. The product price and localized price match ASC and the paywall disclosure.
5. The app ID and bundle ID in RevenueCat match the submitted binary.
6. Purchase, restore, refund, and entitlement charts are segmented by app
   version and build.
7. The dashboard contains a baseline before the next paywall or pricing change.

### RevenueCat implementation behavior

`StoreService` configures RevenueCat at startup, fetches offerings, filters to
the lifetime package, refreshes intro eligibility, purchases, restores, and
applies customer information. `PaywallView` uses a custom SwiftUI interface;
it is not RevenueCat's hosted/paywall UI. RevenueCat impression tracking is
called with custom paywall impression identifiers, which is useful but is not a
complete funnel.

The local source contains no use of `setAttributes`, no customer event API, and
no app-specific usage instrumentation beyond paywall impression calls and
purchase/restore operations. This is a measurement gap, not a reason to change
the privacy disclosure in this audit. The user specifically excluded a review
of RevenueCat tracking versus the app's data-collected statement.

### Recommended bucketed attributes

If RevenueCat attributes are selected as one measurement sink, use coarse,
non-PII, low-cardinality values. Do not send athlete names, raw race names,
contact IDs, bibs, notes, or raw result payloads. Do not make an attribute
identity key that would allow a person to be reconstructed from the results
provider.

| Attribute | Values or shape | Set or update at |
| --- | --- | --- |
| `app_version` | marketing version | `IronSplitsApp.swift`, after store startup |
| `build` | build number | `IronSplitsApp.swift`, after store startup |
| `release_cohort` | release date or controlled cohort ID | app startup |
| `funnel_stage` | `new`, `search_started`, `athlete_claimed`, `locker_loaded`, `race_opened`, `compare_eligible`, `paywall_seen`, `purchase_started`, `race_book_unlocked`, `export_completed` | update only on durable stage changes |
| `claimed_result_count_bucket` | `0`, `1`, `2_4`, `5_9`, `10_plus` | `LockerStore` after refresh |
| `complete_race_count_bucket` | same coarse buckets | `LockerStore` after refresh |
| `race_kind_count` | small bucket such as `1`, `2`, `3_plus` | locker normalization |
| `has_personal_best` | `true` or `false` | after result load |
| `has_podium` | `true` or `false` | after result load |
| `compare_eligible` | `true` or `false` | `RaceBookView` when comparable data is known |
| `paywall_trigger` | `race_book_compare`, `race_book_export`, `upgrade` | `PaywallView` init or appearance |
| `paywall_variant` | controlled variant ID | paywall appearance |
| `paywall_product_id` | product ID, if displayed | product load |
| `paywall_price_bucket` | coarse price bucket, not raw if unnecessary | product load |
| `paywall_session_count` | `1`, `2`, `3_plus` | `PaywallGate` state |
| `export_format` | `pdf`, `image`, `both` | export action |
| `export_outcome` | `success`, `cancelled`, `failed` | export completion |
| `restore_outcome` | `success`, `none`, `failed` | restore completion |
| `feed_state` | `cached_loaded`, `fresh_loaded`, `failed`, `page_limit`, `empty` | `ResultsFeed` and `LockerStore` |
| `pattie_mode` | `text`, `voice`, `media` | Pattie surface use |
| `pointer_download_count_bucket` | `0`, `1`, `2_plus` | pointer cache |

Do not update RevenueCat for every screen appearance. Prefer durable milestones,
local aggregation, and a single upload at meaningful transitions. Confirm the
supported RevenueCat SDK API and rate limits for the pinned SDK version before
implementing attributes.

### Exact instrumentation insertion points

- `IronSplitsApp.swift`: set app version, build, release cohort after
  `StoreService.start()` succeeds. Set a local launch ID for deduplication.
- `StoreService.start`: record configuration success/failure and product-load
  start. Do not mark Pro from a UI test flag in Release.
- `StoreService.fetchProducts`: record offering loaded, product missing,
  offering empty, and price/product mismatch states.
- `StoreService.purchase`: record purchase started, success, cancellation,
  pending, and failure class. Never include raw error text if it can contain
  account or transaction data.
- `StoreService.restorePurchases`: record restore result and whether entitlement
  state changed.
- `StoreService.apply`: record entitlement state transition, not every customer
  info refresh.
- `AthleteSearchView.runSearch`: record search mode, latency bucket, result
  count bucket, and no-result outcome.
- `LockerStore.claim` and refresh: record identity-saved separately from first
  usable-locker-loaded, plus cached versus fresh state.
- `RaceBookView`: record compare eligibility, preview interaction, paywall
  trigger, export start, and export result.
- `PaywallView`: record impression, product-load state, selected package,
  purchase start, restore start, close, and entitlement transition.
- `RaceDetailView`: record a review-eligible positive moment only after the
  result is complete and only once per qualifying race/session.
- `PointerMediaCache` and `PointersView`: record download/cache state only if
  pointer operations are important to the product decision.

## Paywall and A/B test audit

### Current paywall behavior

`PaywallView` is a custom native SwiftUI paywall with triggers for:

- `raceBookCompare`,
- `raceBookExport`,
- `upgrade`.

It tracks custom impression IDs, fetches the offering, renders plan cards,
shows a one-time lifetime disclosure, provides purchase and restore controls,
and displays retry/error states. `PaywallGate` caps repeated appearances within
the session at two per trigger. This cap may protect user experience but is not
currently measured against conversion or frustration.

The plan card code contains trial, monthly, yearly, and lifetime display paths,
but the active StoreService plan list contains only lifetime. Screenshot mode
also contains inactive plan modes. Treat those branches as dead or test-only
until a real product configuration reaches them.

### High-value experiments for lifetime-only

Run experiments after the release unlock bug is fixed and after the product
configuration is verified.

| Test | Control | Variant | Primary metric | Guardrails |
| --- | --- | --- | --- | --- |
| Contextual compare | generic Race Book paywall | copy and preview tied to the selected comparable races | purchase success per eligible compare user | paywall close, export use, support complaints |
| Contextual export | generic Race Book paywall | show one preview page and explain lifetime export | purchase success per export-intent user | export completion, refunds, paywall repeat rate |
| Preview depth | paywall on first locked action | one useful preview result before paywall | purchase start and success | time to value, session abandonment |
| Benefit order | feature list then price | concrete output then price | purchase success | disclosure comprehension, refund rate |
| CTA copy | `Unlock Race Book` | `Unlock compare and export` | purchase start | cancellation and support contacts |
| Paywall timing | immediate on locked action | delayed until user sees why comparison matters | purchase success per eligible user | retention and repeated paywall views |
| Restore discoverability | restore below fold | restore visible next to purchase | successful restore per returning user | accidental purchase starts |
| Loading state | spinner only | clear product-loading explanation and retry | completed product-load rate | dismissal during load |

Use stable assignment, one variant per user, and a release cohort. Report
impressions, eligible users, product loaded, purchase start, purchase success,
cancelled, pending, restore success, paywall close, and 7-day retained use.
Do not count an impression as an eligible user if the offering failed to load.
Do not use purchase revenue as the only success metric because a variant can
raise short-term purchases while harming retention or increasing refunds.

### Paywall failure modes to test

- Offering request fails on first launch.
- Offering loads with no lifetime package.
- Product price differs from local disclosure.
- Purchase is pending and the user leaves the screen.
- Purchase succeeds but customer info refresh is delayed.
- Restore succeeds for a legacy entitlement alias.
- User dismisses and reopens the paywall twice in the same session.
- Network fails after the user taps purchase.
- StoreKit test environment has no product.
- The Release build is accidentally already Pro.

Every path should end in an understandable state. Never show a purchase CTA
that implies a trial if no trial is attached to the product.

## Ratings and review funnel

### Current funnel

`ReviewPromptTracker` stores launch count, first-open date, distinct-use days,
positive-moment count, pending prompt state, and cooldowns in UserDefaults. The
thresholds are approximately five launches, seven days since first open, three
positive moments, three distinct days, a 120-day prompt cooldown, and a 30-day
soft-defer cooldown.

`RootTabView` handles review notifications and presents `ReviewPromptSheet`.
The sheet offers a positive rating path that opens the App Store write-review
URL and a feedback path using email. Settings also has a manual rate/feedback
entry point. `AppStoreReviewLinks` uses ASC app ID `6803727074` and the current
storefront country when available.

The self-selection design is good: users who choose feedback can avoid being
sent directly to the store. However, the passive trigger currently records a
positive moment in `RaceDetailView` before checking completion state. A DNF,
DNS, DQ, incomplete load, error, or repeated open can therefore contribute to a
prompt. This is the highest-confidence review-funnel bug.

### Review funnel changes

Record a positive moment only when all of the following are true:

- the race result is complete and valid,
- the screen is not showing an error or loading state,
- the event has not already counted for the current installation,
- the user has completed a meaningful action or reached a stable result,
- no paywall, purchase, network, or sync failure is currently visible.

Potential qualifying moments:

- a complete race detail opened successfully,
- a personal best is displayed,
- a comparison completes successfully,
- a PDF or image export completes successfully,
- a refresh succeeds after a stale state.

Do not prompt directly after an unsuccessful purchase, a result search failure,
an empty feed, or a field-load error. Keep the Settings entry point available.

### Measurement gap

The local review funnel does not report remotely whether the system prompt was
shown, whether the user selected rating or feedback, or whether the App Store
write-review link completed. Since ASC currently shows `Waiting for Review`,
there is no reliable live rating baseline in the available context. After public
release, record only privacy-reviewed coarse outcomes and compare:

- eligible users,
- prompt shown,
- soft defer,
- feedback selection,
- store-link selection,
- rating and review trend in ASC,
- support contacts and negative review themes.

Do not optimize for prompt count. Optimize for qualified moments and a stable
rating trend without increasing support complaints.

## Website, terms, privacy, and metadata consistency

### Consistent current claims

The active website, current metadata, paywall, terms, and privacy pages broadly
agree on these points:

- public name `IM Tri Tracker`,
- no account requirement,
- race results and split/rank features,
- free core functionality,
- Race Book as a one-time lifetime purchase,
- no new subscription for the current product,
- independent relationship to the race brand described in the app,
- links to support, privacy, and terms.

The Settings disclaimer and local guide also avoid using official race logos or
brand assets and preserve an independent-app statement. Keep this trademark
and affiliation posture in all future metadata, screenshots, and landing-page
copy.

### URL inconsistency

Fastlane metadata and `scripts/generate-asc-metadata.py` use the GitHub Pages
host, including `https://jackwallner.github.io/ironman/`. `docs/index.html` uses
`https://jackwallner.com/ios/ironman/` as its canonical URL. The two hosts may
serve the same content, but that is not confirmed by repository files alone.

Choose one canonical marketing host and make the other a tested redirect. Then
align:

- ASC marketing URL,
- website canonical tag,
- Open Graph URL,
- download links,
- support and legal links,
- release notes and screenshots where a URL appears,
- any analytics or campaign parameters.

Validate the HTTP status, redirect chain, title, app ID, and legal links for both
hosts after every website deployment.

### Legal language

`docs/privacy-policy.html` is dated August 21, 2026 and describes local data,
requests to the results service, GitHub Pages logs, Apple/RevenueCat purchase
processing, and the current lifetime product. `docs/terms.html` is also dated
August 21, 2026 and describes the current lifetime product while retaining
subscription renewal language for prior users. `docs/support.html` includes
help for missing results and legacy subscription restore/manage/cancel cases.

This is reasonably coherent if legacy subscriptions genuinely exist. The
legacy language should be visually labeled as “for prior subscription customers”
so a new buyer does not infer that the current Race Book purchase renews.

This audit does not flag the app's RevenueCat disclosure as a data-collected
inconsistency, per the explicit scope instruction. Any future privacy review
should still be triggered by a product or SDK change, especially if attributes,
analytics, crash reporting, or a trial subscription are added.

### Web conversion improvements

- Put the primary value proposition and a real result screenshot above the fold.
- Explain the free core versus lifetime Race Book boundary before the download
  CTA, without making the free experience sound crippled.
- Add a direct “how it works” sequence: search name, claim result, inspect
  splits, compare/export.
- Add a sample/demo path for users who do not yet have a result.
- Use consistent product naming in page title, social preview, app links, and
  legal headers.
- Add release/build provenance to internal deployment notes, not public copy.
- Ensure support links for no-results, stale results, and purchase restore are
  discoverable from both site and app.

## Crash, regression, and watchdog audit

### Current capability

No crash-reporting SDK, MetricKit integration, hang detector, signpost-based
performance telemetry, external analytics sink, or email notification path was
found in the local source. There are local `os.Logger` calls in services such
as RevenueCat, pointer media, and Pattie voice, but local logs do not create a
fleet-wide live alert.

The app does have useful user-facing handling for several failures:

- remote feed config validation and fallback,
- cached locker data during refresh failure,
- field-load retry,
- product-load retry,
- purchase pending/cancelled/error states,
- pointer download progress and retry/cache behavior,
- export error presentation.

These states are not observable as aggregate production signals. A script on a
MacBook can inspect ASC exports, MetricKit payloads, local log archives,
RevenueCat exports, and synthetic endpoint checks. It cannot reliably detect a
live user's crash from the repository alone.

### Operational signals to collect

#### Release health

- ASC build processing, review, and release status.
- Crash-free users and crash-free sessions by build.
- Crash count, affected users, and top exception or termination reason.
- Hang rate and launch failure rate.
- OS version, device family, and app version dimensions.
- 24-hour, 72-hour, and 7-day comparison against the prior build.

#### Activation health

- search start to first result latency,
- no-result rate,
- claim completion rate,
- first usable locker load,
- cached versus fresh first load,
- feed config and proxy error rate,
- page-limit and empty-result rate.

#### Purchase health

- paywall impression by trigger,
- offering loaded rate,
- missing product rate,
- purchase start,
- purchase success,
- cancellation,
- pending duration,
- restore success,
- entitlement mismatch,
- refund and revoke rate,
- lifetime revenue per activated user.

#### UX health

- Race Detail successful load,
- field-load failure and retry,
- compare eligibility and completion,
- export start and completion,
- pointer download completion and time to first play,
- review prompt eligibility and outcome,
- support entry from no-results or purchase failure.

### Regression policy for new releases

For every release, create a baseline record containing:

- marketing version and build,
- git commit,
- archive timestamp,
- ASC submission ID or build ID,
- RevenueCat offering/product configuration revision,
- feed config revision and proxy URL,
- screenshot and metadata commit,
- test device and iOS version.

Compare at least 24 hours, 72 hours, and seven days after release. Alert on a
material increase in affected users or crash-free-session degradation, not on a
single isolated crash. Segment by build first, then device, OS, flow, and
territory. Roll back or pause acquisition when a regression is concentrated in
the new build and affects activation or purchase-critical paths.

### Scaffold for the requested MacBook watchdog

The future script should be configurable and read-only by default. It should
accept inputs from one or more of these sources:

- ASC API credentials and app ID `6803727074`,
- exported ASC crash and analytics CSV files,
- local MetricKit JSON payloads,
- RevenueCat read-only API exports,
- a local JSONL event stream from the app,
- endpoint health checks for the GitHub Pages feed config and results proxy.

It should maintain a local state file keyed by app ID, build, metric, and
observation window. On each run it should:

1. Fetch or read the latest data.
2. Normalize dates, versions, error classes, and counts.
3. Compare the current window with the previous build and trailing baseline.
4. Apply thresholds and minimum sample counts.
5. Emit a concise report with evidence and confidence.
6. Optionally send an email only when an alert transitions from clear to firing.
7. Record the last alert state to suppress duplicate notifications.

Useful initial alerts:

- new build has any crash affecting more than a configurable number of users,
- crash-free sessions fall by a configurable percentage with a minimum session
  count,
- launch or hang rate increases above a threshold,
- first-result success falls below baseline,
- feed config or proxy health check fails repeatedly,
- paywall offering load or product availability falls below baseline,
- purchase success falls while paywall impressions remain stable,
- restore failures increase for returning users,
- export or compare failures increase after a build,
- website/legal URL returns a non-success status or unexpected title,
- metadata and local identity checks disagree.

The script should explicitly say “no data source configured” rather than report
zero crashes or zero trials. It should never infer that an absent export means
the system is healthy.

### Fleet scanner requirements

The future cross-repository scanner should accept an explicit list of app roots
and produce machine-readable JSON plus a Markdown report. For Ironman, it should
check at least:

- bundle ID, ASC app ID, display name, product name, RevenueCat app/project IDs,
- `RACE_BOOK_TEST_UNLOCK` in Release settings,
- production RevenueCat key usage in simulator code/config,
- StoreKit product IDs and RevenueCat product IDs,
- offering/package/entitlement names in source and setup scripts,
- active product model versus trial/subscription claims in copy,
- current metadata brand versus legacy names,
- app-review link ID,
- website canonical and metadata URLs,
- terms/privacy/support URL reachability,
- screenshot manifest versus capture test versus actual files,
- stale capture provenance versus current HEAD,
- XcodeGen drift,
- untracked or dirty files before release,
- tests and scripts that reference removed views or assets,
- stale agent documentation claims about tabs, paywalls, or release settings,
- release notes and metadata backup directories.

The scanner should classify findings as confirmed mismatch, missing evidence, or
manual review. It should not attempt to prove a live crash from static files.

## Cursor, Claude, and Codex documentation hygiene

### Current state

The repository has a root `CLAUDE.md` but no separate repository-level
`AGENTS.md` or Cursor-specific instruction document in the inspected inventory.
The root guide is useful and contains important trademark, App Store, RevenueCat,
and release guidance. It is not currently a reliable source of truth because
several operational sections are stale:

- `CLAUDE.md:82-84` says the app has five tabs including Bests and Resume. The
  current `RootTabView` has four tabs: Locker, Pattie, Race Book, and Settings.
- The same section describes Pattie as preserving a five-tab bar, which no
  longer matches the root navigation.
- `CLAUDE.md:90-99` says nothing is gated, `ProGate.everythingUnlocked` is true,
  and the paywall is not presented. Current source gates Race Book compare and
  export and presents `PaywallView`.
- `CLAUDE.md:101-102` describes the old `Iron Splits+` entitlement as if it is
  the active product contract. Current code has `pro` as primary and retains
  aliases for compatibility.
- The review-funnel guidance is broadly directionally correct but should name
  the current positive-moment bug and deduplication requirement.

`DESIGN.md` is titled `IM Iron Splits: design system`, which is acceptable as an
internal historical file only if its public-brand status is explicit. `README.md`
also contains stale pre-ship checkboxes about GitHub Pages and pointer media
that are already represented by current `docs` assets and runtime code.

### Recommended documentation layout

Do this in a separate documentation-only change, not while implementing this
audit:

```text
CLAUDE.md                    canonical active project guide
AGENTS.md                    symlink or exact pointer to the canonical guide
docs/agent/README.md          map for Claude, Cursor, and Codex
docs/agent/release.md         release gates and provenance checklist
docs/agent/store.md           ASC metadata, screenshots, and naming contract
docs/agent/purchases.md       RevenueCat and StoreKit contract
docs/agent/runtime.md         feed, cache, watchdog, and known failure states
docs/adr/                    durable decisions such as lifetime-only pricing
docs/archive/                 explicitly stale historical guides and reports
audit823.md                  current audit artifact, not agent instructions
```

The canonical guide should include a short “current state” block with:

- public name `IM Tri Tracker`,
- repository slug and bundle ID as legacy identifiers,
- current tab structure,
- current paid product model,
- current ASC app ID and status source,
- current RevenueCat IDs,
- current screenshot source of truth,
- release unlock policy,
- links to the runtime and release docs.

Agents should be told to prefer source/config over historical reports and to
never upload from backup metadata directories. Historical audits should be
dated and moved out of the active instruction path once their findings are
resolved.

## Prioritized implementation plan for the next agent

### P0: before the next paid release

1. Remove `RACE_BOOK_TEST_UNLOCK` from Release settings in `project.yml` and
   regenerate the project. Inspect the generated project for the same condition.
2. Add a CI or release-script assertion that fails if the Release configuration
   contains the test unlock.
3. Verify the archived binary uses real RevenueCat purchase state and that a
   StoreKit sandbox/test build is the only build using test unlock behavior.
4. Reconcile the ASC screenshot manifest, capture UI test, raw captures,
   rendered captures, and upload folder from one commit. Decide whether Bests is
   a standalone screenshot or a Race Book section.
5. Do not submit a build whose paid boundary or screenshot provenance is
   uncertain.

### P1: before optimizing conversion

1. Decide lifetime-only versus subscription/trial. Record the decision in an
   ADR and align code, ASC, RevenueCat, metadata, site, support, terms, and
   privacy.
2. Add a read-only RevenueCat configuration check for app, product, package,
   offering, entitlement, and price.
3. Add activation and purchase funnel events or bucketed attributes with no raw
   user data.
4. Fix positive-moment review tracking to require a complete, deduplicated,
   meaningful result.
5. Add no-results help, a sample path, bounded slow-search recovery, and a
   claim-versus-sync state.
6. Choose and verify one canonical marketing URL.
7. Refresh `CLAUDE.md` and add a repo-level agent-doc map so stale instructions
   do not reintroduce old tabs or disabled gating.
8. Archive or isolate metadata backups from upload tooling.

### P2: after baselines exist

1. Run the paywall experiments listed above, one at a time.
2. Add pointer download/cache health signals if the feature is a retention
   priority.
3. Add ASC/MetricKit and endpoint health watchdog inputs.
4. Improve screenshot copy and custom product-page segmentation using ASC
   acquisition evidence.
5. Review accessibility, dynamic type, localization, loading, offline, and
   export behavior on every high-value path.

## Validation plan

The following commands and checks are for the implementing agent. They were not
run during this audit because the current request limited writes to this audit
file.

### Static identity and release checks

```sh
rg -n "RACE_BOOK_TEST_UNLOCK|PRODUCT_NAME|PRODUCT_BUNDLE_IDENTIFIER|6803727074|com\.jackwallner\.ironman|com\.jackwallner\.ironman\.pro" \
  project.yml IronSplits.xcodeproj IronSplits scripts fastlane

rg -n "IM Iron Splits|Iron Splits\+|Ironman App Pro|IM Tri Tracker" \
  CLAUDE.md README.md DESIGN.md IronSplits scripts fastlane docs

git diff --check
```

Run identity scans against an explicit allowlist. Legacy names are allowed in
bundle IDs, compatibility aliases, historical notes, and generator constants,
but not in current public metadata or screenshot copy.

### XcodeGen and tests

In a clean or disposable worktree:

```sh
xcodegen generate
git diff --exit-code -- project.yml IronSplits.xcodeproj/project.pbxproj
```

Then lease a headless simulator from the shared pool and test the current
release-critical paths. Do not open Simulator.app and do not use a named
destination. Never configure the production `appl_` RevenueCat key in a
simulator run.

Required flows:

- fresh onboarding with a valid result,
- no-result and slow-search timeout,
- claim success followed by first feed failure,
- cached locker offline,
- race detail with field success and field failure,
- Race Book preview,
- compare paywall,
- export paywall,
- StoreKit purchase in a test environment,
- restore and pending purchase,
- pointer download and cache hit,
- review prompt after a qualifying complete result,
- dynamic type and localization for paywall and onboarding.

### Screenshot validation

The implementing agent should generate the screenshots from the same commit as
the binary, then verify:

```sh
test "$(git rev-parse HEAD)" = "$(jq -r .git_commit fastlane/asc-capture/race-book/capture-report.json)"
```

The exact command may need to account for a capture commit field format, but the
principle is mandatory: stale capture reports must fail review. Compare the
capture manifest, UI test attachment names, raw files, rendered files, and
ASC submission files before upload.

### Website and legal checks

For both the GitHub Pages and custom-domain URLs, verify:

- success status and expected redirect,
- same public brand and app ID,
- canonical URL points to the chosen host,
- download link resolves to app ID `6803727074`,
- support, privacy, and terms routes resolve,
- current lifetime/no-subscription claim is consistent,
- legacy subscription language is clearly labeled,
- independent-app disclaimer is present where race-brand references appear.

### RevenueCat checks

Use a read-only API or dashboard export and retain a timestamped baseline with:

- project ID and app ID,
- offering identifier,
- package identifier,
- product identifier and localized price,
- entitlement identifier and attachment,
- active customer and purchase counts,
- purchase, restore, refund, and revoke outcomes,
- app version/build dimensions.

Do not treat a missing dashboard export as zero revenue, zero trials, or zero
crashes.

## Open decisions and data gaps

These require an owner decision or live evidence rather than static inspection:

1. Was the ASC `Waiting for Review` build compiled with
   `RACE_BOOK_TEST_UNLOCK`?
2. Is `IM Tri Tracker` the final public name, with `IM Iron Splits` retained
   only as repository and compatibility history?
3. Is Race Book permanently lifetime-only, or is a subscription/trial planned?
4. Does RevenueCat currently attach the lifetime product to `pro` in the public
   offering, and are the two fallback aliases still needed?
5. Which host is the canonical marketing URL?
6. Is Bests intentionally embedded in Race Book, or should it remain a top-level
   store story?
7. Which existing ASC screenshot set, if any, was actually submitted with the
   current review build?
8. What is the first usable result activation rate and median time to value?
9. What are the current paywall impression, purchase, restore, refund, and
   retention baselines?
10. What production source will provide crash and hang data?
11. Are legacy subscription customers active enough to require the current
    compatibility copy and entitlement aliases?
12. Which locales generate qualified downloads and should receive further
    localization investment?

## Final handoff checklist

Before another agent implements changes, hand off these concrete instructions:

- Treat `IM Tri Tracker` as the current public name.
- Treat `com.jackwallner.ironman`, repository `ironman`, and old RevenueCat
  aliases as compatibility identifiers, not new public copy.
- Fix the Release test unlock first.
- Reconcile screenshot assets from the current binary and current navigation.
- Do not call the current lifetime product a trial.
- Add measurement before drawing conversion conclusions.
- Fix positive review eligibility before increasing review prompts.
- Preserve the no-results and offline recovery paths while adding telemetry.
- Choose one canonical website host.
- Refresh stale agent docs before asking Cursor, Claude, or Codex to make broad
  product changes.
- Keep all future release artifacts tied to a commit, build, ASC record, and
  RevenueCat configuration revision.

