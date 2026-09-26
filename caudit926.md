# Customer experience audit, 2026-09-26

Scope: a code-level read of every view and the services behind them (`IronSplits/Views/*`,
`Shared/Services/*`, `Shared/Models/*`), plus the fastlane metadata, `Info.plist`, `project.yml`
and the shipped App Store screenshots in `fastlane/screenshots/en-US`. Nothing was built or run,
and no file other than this one was changed. The working tree already had uncommitted edits to
`IronSplitsApp.swift`, `StoreService.swift` and some deleted Pattie images. This audit did not
touch them.

Severity: **P0** means it breaks a promise, loses data, or carries App Review risk. **P1** means
it clearly hurts activation, retention or conversion. **P2** is polish.

Status: **complete for code, partial for live UI.** Every finding was verified against the
code. The build succeeded on a leased headless simulator (agent-sim-4, iOS 26.3), but
CoreSimulator wedged on the machine: `simctl install`, `simctl launch` and
`simctl io screenshot` all hung for several minutes, and so did another agent's launch on a
different device. After two attempts the lease was checked back in. Findings that depend on
rendered geometry are therefore marked **(layout math, confirm on device)**, and Section 13
lists the on-device checks still worth doing.

---

## 0. Top ten, in order

1. **P0: The headline promise, "Your race splits, ranked", has no screen behind it.** The Bests
   leaderboard was removed. `RaceAnalytics.standings` is only called internally, and no view
   ranks races by swim, bike, run, transitions or finish. The subtitle, the description ("See
   races ranked by swim, bike, run, transitions or finish time") and screenshot 06 ("Find your
   fastest split") all sell a feature the app no longer has. This is both a Guideline 2.3.1
   accuracy risk and the first letdown for a new user.
2. **P0: The App Store screenshots show a different app.** They show the old tab bar (Locker,
   Bests, Pattie, Resume, Settings), the old orange accent, and a Bests tab. Screenshot 01 shows
   "Race Book unlocked" with a Done button, which is the exact state App Review rejected under
   2.1(b). They also feature a real athlete's name and results ("Daniel Winek").
3. **P0: Swipe-back is broken on the most-visited screen.** `RaceDetailView`,
   `AskPattieTopicList` and `AskPattieAnswerList` use `.navigationBarBackButtonHidden(true)` with
   a custom `TriBackButton`. SwiftUI disables the interactive pop gesture when you do that, and
   nothing in the codebase turns it back on (no `interactivePopGestureRecognizer` handling).
   `AskPattieView.swift` even has a comment claiming "the edge swipe works". DESIGN.md §7
   requires back-swipe.
4. **P0: Race notes are included in the shareable image by default.** `RaceBookOptions`
   defaults `includeRaceNotes = true`, and the "tall shareable image" meant for social or
   messages dumps private conditions, nutrition and gear text. The on-screen copy says notes are
   "included only when you choose to export". That is technically true, but the default is on.
5. **P1: Common-name users can be silently missing from search.** `searchAthletes` caps at
   2 pages × 250 rows with `allowTruncation: true` and **no `$orderby`**. For "John Smith" the
   500 rows the proxy returns are arbitrary, so the right John Smith may never appear, and the UI
   gives no hint that results were truncated. Onboarding is the only door into the app.
6. **P1: Race Book (the paid tab) opens with the paywall, not the value.** Card order is: intro,
   "Unlock to export", a ten-toggle options card, and only then career stats, PBs and
   progression. A free user sees a locked button and ten switches for a product they cannot use
   before seeing anything they can.
7. **P1: The paywall sells free features and shows no product.** `PaywallTrigger.proFeatures`
   lists "Career personal-best and progression timeline", which is free in `RaceBookView`. The
   paywall never shows what the PDF or image actually looks like, even though that artifact is
   the thing being sold.
8. **P1: Unrelated store errors leak into Settings.** Settings renders `store.lastError`. That
   string is also set by `fetchProducts()` and `updateCustomerProductStatus()` at launch, so an
   offline launch shows a red "Couldn't load the Race Book unlock…" under Restore purchases
   although the user did nothing.
9. **P1: Explore shows "Racing since 2,015".** `ExploreAthleteView.profileHeader` uses
   `Text("Racing since \(years.lowerBound)")`. `LocalizedStringKey` interpolation of an `Int`
   applies grouping, so US locales render "2,015". The Locker header avoids this with
   `String(...)`.
10. **P1: Haptics are off by default.** `Haptics.isEnabled` defaults to `false`, and Settings
    says "It is off by default". DESIGN.md §6 says "Haptics on anything that means something" and
    "A polished-looking interface that does not answer the thumb reads as broken." Every
    `.triPress` and `TriChip` in the app is silent for anyone who never opens Settings.

From the second pass, these five belong right below the ten above:

- **P1, 10.1:** automatic Pattie lines play through the Silent switch.
- **P1, 10.4:** the Pattie pet sits over the Locker tab and likely steals its taps.
- **P1, 11.5:** downloaded episodes go into iCloud backups.
- **P1, 12.3:** the privacy policy says "no analytics", but usage counts are synced to
  RevenueCat.
- **P1, 13.1:** the main secondary text colour and the "positive" green fail WCAG AA contrast
  in light mode.

---

## 1. Store listing and first impression

### 1.1 Promise vs product (P0)
- Subtitle "Your race splits, ranked" and the description's "YOUR SPLITS, RANKED" section
  describe the removed Bests leaderboard. Pick one of two fixes:
  - **Restore a leaderboard** (recommended, because it is the app's reason to exist and
    `RaceAnalytics.standings`, `SplitStanding.gapToBest` and `PattieMode.Moment.bests` /
    `.bestsFiltered` are all still there and unused). It could live inside the Race Book as a
    free "Rankings" section, or as a segmented view inside Locker, so the tab bar stays at five.
  - Or rewrite the subtitle, description and screenshot 06 to match what ships.
- Description also says "Personal bests are marked on every leg". The Locker marks PB legs only
  on rows, and only when there are two or more comparable races. That is fine, but the wording
  implies more.

### 1.2 Screenshots are stale (P0)
Seen in `fastlane/screenshots/en-US/01..07`:
- The tab bar is Locker / Bests / Pattie / Resume / Settings. The app now ships Locker /
  Explore / Tips / Race Book / Settings (`RootTabView.Tab`).
- The accent is orange. `TriPalette.sunrise` is now runner red.
- 01 shows "Race Book unlocked" plus a "Done" button (the pushed-sheet variant). A reviewer who
  compares it to the build sees a locked product. It is the 2.1(b) story again.
- 06 is the Bests leaderboard, which no longer exists.
- 07 shows the segmented control "Ask Pattie / All episodes" inside a tab labelled "Pattie". The
  shipping tab is "Tips".
- Explore, the one new top-level feature, appears nowhere.
- A real person's name and full results ("Daniel Winek, Madison, WI") appear in 03, 04 and 06.
  They are public results, but using an identifiable private individual's record in
  advertising without consent is a real risk. Use a consenting athlete (Pattie) or a fictional
  fixture.

### 1.3 Localized listings for an English-only app (P1)
`fastlane/metadata` has 40+ locales, with translated German copy among them. The app has no
`.xcstrings` or `.lproj` and hardcodes English everywhere. A German user who installs from a
German listing lands in English UI. Either localize the four highest-volume triathlon markets
(de-DE, fr-FR, es-ES, pt-BR) or trim the listings to English plus light keyword localization,
and say "English only" in each.

### 1.4 Launch screen (P2)
`UILaunchScreen` is an empty dict, so launch is a system-background flash followed by a navy
nav bar. Set `UIColorName` to a canvas or deep asset colour so the first frame matches.

### 1.5 Status bar (P2)
`UIStatusBarStyleLightContent` with `UIViewControllerBasedStatusBarAppearance = false` forces a
white status bar everywhere. Every stack uses the navy `triNavBar`, so it mostly works. But over
`.medium` sheet detents (the review prompt) and the canvas-topped paywall scroll region, white
status text can land on light content.

---

## 2. Onboarding and search (the only door in)

### 2.1 Truncated search with no ordering (P1)
`ResultsAPI.searchAthletes`: `pageLimit: 2, pageSize: 250, allowTruncation: true, orderBy: nil`.
- For common names the athlete may not be in the returned 500 rows, and nothing tells them.
- `collapseToAthletes` then sorts by `knownRaceCount`, so a prolific namesake always outranks
  the user.
- Fixes, cheapest first:
  - When truncation happened, show "Lots of people share this name. Add your city or state
    to narrow it." Then accept "John Smith Madison" and add a third clause on
    `address1_city startswith`. `nameFilter` already takes up to three words but only matches
    them against first and last name.
  - Order upstream by `wtc_EventId/wtc_eventdate desc` so recent racers (the likely users)
    surface first.
  - Carry a `truncated` flag out of `fetch` so the view can show the hint.

### 2.2 "No athletes found" copy blames the user (P1)
The empty state says "Try the name exactly as it appeared on your race entry…". A frequent real
cause is that the person only has running or other triathlon results. `collapseToAthletes`
drops every row where `!result.kind.isSupported`, so a Rock 'n' Roll-only runner or a
sprint-only triathlete gets "No athletes found" and assumes the app is broken. Distinguish the
two cases: if the unfiltered rows were non-empty, say "We found results for this name, but only
full and half-distance triathlons are supported."

### 2.3 Search thresholds disagree (P2)
Typing debounces at 3 characters, but pressing Search runs at 2 (`runSearch()` guards
`>= 2`). A two-letter surname like "Ng" or "Li" never auto-searches and only works by pressing
the return key, which nothing hints at.

### 2.4 Double-claim race (P2)
`claim(_:)` sets `claiming` but rows are not disabled. Tapping a second row during the ~1.5s
claim starts a second `locker.claim`. The generation counter makes the last tap win, but the
first row's spinner and the root view transition flicker. Disable the list while `claiming !=
nil`.

### 2.5 No confirmation before a claim or change (P2)
Tapping any row instantly replaces the locker, including from Locker's toolbar "Change" button,
which sits in the prime top-right slot. Changing the athlete wipes the cached results (notes
survive). Suggestions:
- Move "Change" into the `…` menu (the menu currently holds a single item, Refresh, which
  pull-to-refresh already covers).
- In the change-athlete flow, show a one-line confirm: "Replace Pattie Wallner with John
  Smith?"

### 2.6 Deep search wait has no escape (P2)
The `contains` fallback can take about 30 seconds, with only a spinner and text. Add a "Stop" or
"Edit name" affordance and a hint ("Try your registered first name, e.g. Patricia") while it
runs.

### 2.7 Registered-name hint is buried (P2)
The most useful tip, "often a full legal first name", only appears after a failure. Put it in
the intro blurb so users try "Patricia" before "Pattie".

### 2.8 Settings "Find another registered name" is the right idea, but hard to find (P2)
Split careers (the `contactIDs` merge problem) are common. After a claim, if the athlete's
`knownRaceCount` is small or the career has gaps, the Locker could offer "Missing a race? Add
another registration" inline, not just in Settings.

---

## 3. Locker

### 3.1 The stat header assumes triathlon only (P2)
`LockerHeader` always shows Full and Half tiles, even when one is 0 (screenshot 04: "0 HALF").
Hide zero tiles, or show Starts/DNF instead.

### 3.2 No grouping or search for long careers (P2)
A 25-race career is one flat list. Group by year using section headers, and add
`.searchable` over race names. The kind chips help, but name search ("Wisconsin") is what
veterans will want.

### 3.3 PB computation cost (P2)
`personalBestLegs(for:)` calls `RaceAnalytics.isPersonalBest` for 5 disciplines per row. Each of
those calls runs `standings(...)` again, which filters and sorts the whole result set. That is
O(rows × 5 × n log n) per body evaluation. It is fine for 20 races and janky for 80+. Compute a
`[resultID: Set<Discipline>]` once per `locker.results` change.

### 3.4 Race Book card duplicates the tab (P2)
"Build your Race Book" in the Locker pushes `RaceBookView` inside the Locker stack, and the
Race Book tab is one tap away. Two paths to the same screen with different back behaviour.
Either switch tabs from that card, or replace it with something the tab does not already give
(for example, "Latest race: see how it compares").

### 3.5 Refresh warning styling (P2)
`refreshWarning` (page-limit reached) renders in `TriPalette.negative` with a warning triangle.
It is not an error the user can fix, and "refresh and try again" will hit the same cap. Reword
it, or raise `maxPages` via `api-config.json`, since the hotfix channel exists for exactly this.

### 3.6 No "new result" moment (P1, retention)
The app has no hook for bringing someone back after their next race. Ideas that need no
backend:
- On refresh, diff the result IDs. When a new race lands, celebrate it (a Pattie moment, a
  banner, "New PB on the bike").
- A background app refresh task, plus a local notification ("Your IRONMAN Wisconsin splits are
  in"). This is the single strongest retention loop available, since results post within hours
  of a finish.

---

## 4. Race detail

### 4.1 Swipe-back disabled (P0), see Top ten #3
Fix: remove `.navigationBarBackButtonHidden(true)` and style the system back button, or add a
small `UINavigationController` extension that re-sets `interactivePopGestureRecognizer.delegate`.
The same fix applies to `AskPattieTopicList` and `AskPattieAnswerList`.

### 4.2 Nav title is just the year (P2)
`.navigationTitle(String(result.year))`. With a back gesture or VoiceOver rotor, "2025" says
nothing. Use the race name, since the hero repeats it anyway, or the short name.

### 4.3 Field percentile is overall only (P1, value)
"Against the field" uses every finisher. What age-groupers care about is their division, and
gender second. The field rows already carry `ageGroup`, so add a Division / Gender / Overall
toggle on the card. This is probably the most-requested feature an age-grouper would ask for,
and it is almost free given the data already loaded.

### 4.4 Field loads every time, uncached (P2)
`loadField()` fetches the whole event (up to 12 × 500 rows) on every detail open, with state
kept in `@State`. `useProtocolCachePolicy` may or may not help, depending on proxy headers.
Cache per `eventID` in memory, or on disk for past events (they never change), so reopening a
race is instant and works offline.

### 4.5 Note editor can lose work (P1)
`RaceNoteEditor` has no `.interactiveDismissDisabled` when dirty, and Cancel discards without
asking. A long post-race write-up is lost to an accidental swipe-down. Add a dirty check and a
"Discard changes?" confirm. There is also no way to delete a note except clearing all four
fields.

### 4.6 Review prompt fires on opening any race, including DNFs (P1)
`RaceDetailView.task` calls `ReviewPromptTracker.recordPositiveMoment()` unconditionally, then
the root presents the enjoyment sheet over the race the user just opened. Opening a DNF is not a
positive moment, and interrupting someone mid-read hurts ratings. Record positive moments only
for complete races and for PB races, and present the prompt on back-navigation or after a
successful export.

### 4.7 No single-race share (P1, growth)
The most shareable moment in triathlon is one finish. A free, designed 9:16 "race card" (race
name, finish, splits bar, division place, PB badges) with the app name on it is the best organic
acquisition channel the app could have. Today the only share path is the paid, text-heavy Race
Book export.

### 4.8 "Compare with another race" entry point (P2)
Compare lives only at the bottom of the Race Book. A "Compare" button on the race detail, with
this race preselected as one side, is where the intent actually occurs.

### 4.9 PB badge on T1/T2 rows (P2)
`splitsCard` passes `isPersonalBest` for `.t1` and `.t2`, but `Discipline.rankable` deliberately
folds these into `transitions` because "nobody chases a T2 personal best on its own". The
detail can still badge them. Pass `false` for t1 and t2 to match the rest of the app.

---

## 5. Race Book (the paid tab)

### 5.1 Reorder around value first (P1)
Current order: intro, export (locked), ten toggles, career, distance chips, PBs, progression,
disclaimer, compare (locked). Suggested order:
1. Career at a glance
2. PBs
3. Progression (with a chart, see 5.3)
4. Compare (teaser showing the delta for the latest two races, blurred past the first leg)
5. Export: a thumbnail of page one of the actual PDF, then the CTA
6. "Customize" disclosure that holds the ten toggles

### 5.2 Two distance selectors on one screen (P2)
"Distances" (multi-select, for export) inside the include card and "Compare by distance"
(single-select, for the preview) look identical and sit close together. Users will expect one to
drive the other. Move the export one inside the Customize disclosure.

### 5.3 Progression is only first vs latest (P1, value)
Two points across different courses (Kona vs Florida) is noise, not progression.
`RaceAnalytics.trend` already exists and is unused. Use Swift Charts for a per-leg trend line
across every race at that distance. Also offer "same race across years" (Wisconsin 2019 vs
2023), which is the only truly like-for-like comparison triathletes accept.

### 5.4 PB rows are not tappable (P2)
`RaceBookBestRow` shows the race name but does not navigate to it. Link to `RaceDetailView`.

### 5.5 Shareable image is a text dump (P1)
`RaceBookBuilder.image` renders `plainText` lines onto a 1170-wide canvas with no height cap. A
long career with splits and notes produces a very tall PNG that platforms crop or downscale
into illegibility. Offer a fixed 1080×1920 designed summary (hero, PBs, podium count) as "Share
image", and keep the full-length version as an option.

### 5.6 Notes default on (P0), see Top ten #4
Default `includeRaceNotes` to `false`, or default it on only for the PDF and off for the image.

### 5.7 Exports go stale silently (P2)
`exports` resets when `exportOptions` changes, but not when notes change or the locker
refreshes. A user who edits a note and taps "Share PDF" shares the old file. Invalidate on
`notes.notes` and `locker.results` changes too.

### 5.8 Zero free exports (P1, conversion)
Nothing lets a free user see their own book before paying. One free export, watermarked
"Made with IM Tri Tracker" (which also markets the app), or a free one-page PDF with the full
book paid, would let people feel the product. The paywall bullet "Unlimited exports…" already
implies a limited free tier exists.

### 5.9 Compare view friction (P2)
- The explainer "Negative changes mean the comparison race was faster" is a sign that the
  labels are wrong. Label the two sides "Earlier" and "Later" (or by date), and show "2:31
  faster" in words instead of a signed number.
- The `Menu` pickers list "Oct 26, 2024, IRONMAN World Championship - Men". Long, and sorted
  newest first. Fine for 5 races, painful for 30.

---

## 6. Paywall and purchase

### 6.1 Feature list claims free features (P1), see Top ten #7
Remove "Career personal-best and progression timeline" (free), and merge the two export
bullets. What is actually paid: compare, and export.

### 6.2 Single radio button (P2)
`planCards` draws a selectable radio card for exactly one product. A radio button with nothing
to choose between reads as unfinished. Replace it with a single price line above the CTA and
put the price in the button: "Unlock Race Book, $X". `StoreService.directCTALabel(for:)`
already builds that string and is unused.

### 6.3 Cancel shown as an error (P2)
Cancelling Apple's sheet shows "Purchase cancelled. Tap again to continue." in the accent red.
A user who cancelled did nothing wrong. Show nothing.

### 6.4 No visual of the product (P1)
Add a rendered page of the user's own Race Book (generated locally, and possibly blurred) to the
hero. The paywall hero is currently a decorative bar motif.

### 6.5 Dead paywall scaffolding (P2, maintenance)
`PaywallGate.shouldPresent`, `purchaseLifetimeDirect`, `paywallBlurCTA`,
`paywallBlurSubtext`, `upgradeCTALabel`, `LockedRow`, the `ProGate.visibleResults` /
`lockedCount` / `isLocked` pass-throughs, the savings/anchor/trial branches in
`PaywallPlanCard`, and the `.monthly/.yearly/.trial` screenshot modes are all unreferenced. They
cause no customer-visible bug, but they make the next paywall change slower and riskier.

### 6.6 Content under the close button (P2)
`content` uses `.ignoresSafeArea(edges: .top)` on the `ScrollView` itself (DESIGN.md: for
backgrounds only). When scrolled, feature text passes under the status bar and the close button,
whose `inkOnDark` glyph then sits on a light surface.

### 6.7 Restore visible when already unlocked (P2)
Settings shows "Restore purchases" and "Already bought Race Book?…" even when
`raceBookUnlocked`. Hide both once unlocked.

---

## 7. Explore

### 7.1 "Racing since 2,015" (P1), see Top ten #9
Use `String(years.lowerBound)`, as `LockerHeader` does.

### 7.2 Recents are lost on relaunch (P2)
`recentAthletes` is `@State`. Persist the last few (IDs, name, location) in `UserDefaults`.
Better still, let users "follow" friends and get the new-result notification from 3.6 for them
too, which gives a reason to reopen the app.

### 7.3 Rows are dead ends (P2)
`ExploreAthleteView` renders `RaceRow` without navigation, while the same row in the Locker
opens a full detail. A user taps, nothing happens, and it reads as broken. Link to
`RaceDetailView`. Note that its notes card would then need hiding for non-owned results, and PB
badges would need to be computed against the explored athlete's results.

### 7.4 Head-to-head (P1, value)
The obvious Explore feature: "Compare with me" at a shared race, leg by leg. Both result sets
are already in memory.

### 7.5 Header can overflow (P2)
The Explore header's `HStack` of four `StatTile`s has no `ScrollView` or `ViewThatFits`, unlike
the Locker. At large Dynamic Type it clips.

### 7.6 Reload on every appear (P2)
`.task { load() }` guards only `.loading`, so it re-fetches after every re-appear, and the
unstructured `Task` is not cancelled on disappear.

---

## 8. Tips / Pattie

### 8.1 Naming is inconsistent (P2)
Tab label "Tips", nav title "Pattie", segmented control "Ask Pattie / All episodes", picker
accessibility label "Pointer view", description section "TRI POINTERS", CLAUDE.md "Pattie tab".
Pick one noun for users.

### 8.2 Who is Pattie? (P1)
A stranger opening "Tips" meets "PATTIE WALLNER / Small things save a whole day" with no
credentials. One line of authority (for example "N-time IRONMAN finisher, Kona qualifier", if
that is accurate) turns a stranger's clips into coaching someone trusts.

### 8.3 Download-before-play (P2)
The player must download the whole file before anything plays (by design, see
`.claude/rules/pointers-and-pattie.md`). On cellular this is a progress bar with no size
estimate. Show the file size up front, and offer "Download all for offline" in the library.
Episodes are 426×240, which looks poor full-screen.

### 8.4 Pattie Mode is invisible (P2)
It is off by default and only discoverable from Settings. A single opt-in card in the Tips tab
("Want Pattie along for the ride?") would surface the app's most distinctive feature to the
people who would like it.

---

## 9. Settings, feedback, polish

### 9.1 Section order (P2)
About sits first. Athlete, Race Book, Units and Appearance are what people come for. Put About
and the legal links last.

### 9.2 Stray error text (P1), see Top ten #8
Scope the Settings error to restore attempts only (keep a separate `restoreError`).

### 9.3 Feedback via `mailto:` only (P2)
`ReviewPromptSheet.sendFeedback` opens a `mailto:` URL and then dismisses. On a device with no
Mail account, iOS shows its own "Restore Mail?" alert and the typed feedback is gone. Check
`canOpenURL`, and fall back to copying the text plus showing the address, or use
`MFMailComposeViewController` with a fallback.

### 9.4 Two-step review pitch (P2)
"Yes, I'm enjoying it" leads to a second "Support an indie app" screen, then the App Store
write-review page. Each extra step loses people. Go straight to `requestReview()` after "Yes",
and keep the write-review link as the explicit option in Settings.

### 9.5 Custom tab bar (P2)
`RootTabView` hides the system tab bar and draws a 64pt-tall floating capsule with
`.dynamicTypeSize(.xSmall ... .large)` clamped on labels. Costs:
- No native tap-to-scroll-to-top or tap-again-to-pop-to-root.
- Accessibility text sizes are ignored in the labels.
- It adds roughly 80pt of permanent chrome, which is why `TriGeo.tabBarClearance` exists.
- On iOS 26 it will not pick up the system Liquid Glass tab bar that every other app gets.

Tap-again-to-pop-to-root at minimum is cheap to add: keep a per-tab path and reset it when
`selectedTab == tab`.

### 9.6 Swim pace in imperial (P2)
`PaceFormat` shows "/100m" regardless of units. US swimmers think in /100yd. With imperial
selected, show yards.

### 9.7 Technical error strings reach users (P2)
"The results service returned an error (502)." and raw `URLError` descriptions surface
directly. Map them to human copy: "The results site is having trouble. Your saved races are
still here."

### 9.8 Doc drift that will mislead the next change (P2)
CLAUDE.md says the app is "IM Iron Splits" with tabs "Locker, Bests, Pattie, Resume,
Settings". The shipping app is "IM Tri Tracker" (`Info.plist`, `PRODUCT_NAME`, every
user-facing string) with Locker, Explore, Tips, Race Book, Settings. Anyone following CLAUDE.md
will write copy with the wrong name.

---

## 10. Pattie Mode and audio

Pattie Mode is off by default and opt-in from Settings, so these only affect people who chose
it. They are also the people most invested in the app.

### 10.1 She talks through the Silent switch (P1)
`PattieVoice.configureSession()` uses `.playback` with `.mixWithOthers`, and the comment says
so deliberately: "`.playback` remains audible when the hardware Silent switch is on". That is
right for the episode player the user tapped. It is wrong for the companion's automatic lines.
`PattieMode.present` calls `voice.playIfQuiet(line.voice)` on tab changes, filter taps, back
navigation and screen appearances. So a phone on silent speaks out loud in a meeting when the
user switches tabs.
- Fix: use `.ambient` (which respects Silent and mixes) for companion lines, and switch to
  `.playback` only for user-initiated playback ("Hear it from Pattie", "Full clip", episodes).
  Or keep one session and only auto-play when `AVAudioSession.secondaryAudioShouldBeSilencedHint`
  is false and the ringer is on.
- Related: `IronSplitsApp` calls `PattieVoice.prepareSession()` at every launch, even when
  Pattie Mode is off. It activates a `.playback` session for a user who has never asked for
  audio. Defer it until the first playback.

### 10.2 Contextual moments say random things (P1)
`PattieMode.present` overwrites the moment's own line with the next tip from the answer tree
("The event deck controls timing. The real answer tree controls the visible tip"). So opening
a PB race, a DNF, or a World Championship result does not get a PB, DNF or Kona line. It gets
whatever swim or nutrition tip is next in rotation. The moment system (`personalBest`,
`didNotFinish`, `worldChampionship`, `claimed`, `veteran`) already exists and has a line deck.
Let those moments keep their own text and voice, and use rotating tips only for the generic
`action` reactions. A companion that reacts to *your* race is the point of the feature.

### 10.3 Reaction frequency (P2)
`quietPeriod` is 0.9 seconds and every `Action` has a 0.9 second cooldown. Tab, filter,
selection, back and refresh all call `pattie.react`. The only real limiter is "not while a
clip is playing", so in practice she speaks again as soon as the previous clip ends and the
user taps anything. Set a per-session budget (for example, one automatic line per 60 to 90
seconds, plus the one-shot moments), and let the avatar tap be the way to ask for more.

### 10.4 The pet likely covers the Locker tab (P1, layout math, confirm on device)
`PattieHostModifier` pads the companion by `PattieCompanion.tabBarHeight (49) + tabBarGap (12)`
plus the bottom safe area, which is sized for a *system* tab bar. The app draws its own:
`tabBar` is a capsule of 64pt plus 2×4pt inner padding, with 8pt above and below, so it is
about 88pt tall above the home indicator. The companion's bottom edge therefore sits about
27pt inside the tab bar, over the leading (Locker) button. The idle avatar is a `Button` whose
action is `pattie.demo()`, so a tap on the top of the Locker tab icon plays a Pattie demo
instead of switching tabs. Derive the offset from the real tab bar height (or put the
companion inside the same `safeAreaInset`).

### 10.5 Battery and motion (P2)
With Pattie Mode on, the idle pet and its accessory each run a
`TimelineView(.animation(minimumInterval: 1/30))` on every screen, all the time, plus an
`animateIdle` loop. That is two 30fps redraw loops for the whole session. Reduce Motion is
respected, which is good. For everyone else, animate only while a line is showing, and fall
back to a static idle frame (or a slow 1 to 2 fps breathing loop).

### 10.6 Auto-dismiss is too fast to read (P2, accessibility)
`PattieCompanion.run` dismisses a bubble after `min(4.0, 1.5 + characters/80)` seconds (or 5
seconds for a catchphrase), unless the clip is still playing. A 250-character tip is gone in
4 seconds when muted, and VoiceOver users may not reach it. Keep it until dismissed when
VoiceOver is running (`UIAccessibility.isVoiceOverRunning`), and scale the time with length
without a hard 4 second cap.

### 10.7 The "giant catchphrase" takeover blocks the screen (P2)
Every fourth tip slot is a full-screen overlay (`giantTakeover`, `zIndex(20)`, full frame)
with a "Keep moving" button. The class comment calls every line "nonmodal", but this one
intercepts every tap for 3 to 5 seconds. Make it a larger bubble, not a full-frame layer, or
let taps pass through outside the card.

---

## 11. Race Book PDF and data handling

### 11.1 Letter size only (P2)
`RaceBookPDFRenderer.pageSize` is fixed at 612×792 (US Letter). Athletes in Europe, Australia
and most of the triathlon world print A4, where Letter scales down and leaves odd margins. Pick
A4 when `Locale.current.region` is not US or Canada.

### 11.2 Finish rate on the cover (P2)
The cover and the one-page layout both print "FINISH RATE" as a headline stat. For an athlete
with a couple of DNFs, the cover of the thing they paid to share says "71%". Show it only when
it is 100%, or move it into the history section, or make it a toggle. Starts, finishes and
podiums already tell the story.

### 11.3 Cover layout with long names (P2)
The name is drawn at 34pt bold in a 410pt column starting at y=108. The location follows it,
but "RACING X TO Y" is fixed at y=226 and the stats card is fixed at y=244. A name that wraps
to three lines collides with those. Measure the name and push the rest down, or shrink the
font to fit two lines.

### 11.4 Exports accumulate in tmp with personal names (P2)
Both files are written to `temporaryDirectory` as "<Name>-race-book.pdf/png" and never
deleted. Minor. The OS clears tmp eventually, but deleting on the next build, or when the view
disappears, is tidier.

### 11.5 Episodes are backed up to iCloud (P1)
`PointerMediaCache` stores downloaded episodes in Application Support/PointerMedia and does not
set `isExcludedFromBackup`. These are re-downloadable media files, so they bloat the user's
iCloud backup. They also break Apple's iOS Data Storage Guidelines, which have historically
been a rejection reason (2.23). Move them to the Caches directory, or set
`URLResourceValues.isExcludedFromBackup = true` on the folder.

### 11.6 Notes have no backup of their own (P2)
Race notes live only in Application Support/race-notes.json. That is covered by a device
backup, but there is no iCloud sync, and the only way to get them out is the paid export.
Someone who writes detailed race notes for years has no free way to keep them if they switch
phones without a restore. A free plain-text or CSV "Export my notes" in Settings is a trust
feature, not a revenue leak.

### 11.7 Duplicate builders (P2, maintenance)
`ResumeBuilder` is dead apart from `statusLabel(for:)`, which `RaceBook` and the PDF renderer
still call. `RaceBookBuilder.plainText` and the PDF renderer each implement the section logic
separately, so the image and the PDF can disagree (for example, the image lists every podium
and the one-page PDF shows the first two). Move `statusLabel` onto `RaceResult` and delete
`ResumeBuilder`.

---

## 12. Website, support and privacy copy

### 12.1 The site sells the missing leaderboard too (P1)
`docs/index.html`: the headline is "Your triathlon history, ranked by split". The pitch says
"a locker you can search, rank, annotate and share". The Race Book section lists
"leaderboards" and "rankings" as free. Same fix as 1.1, and the same accuracy risk.

### 12.2 Support page contradicts the app (P2)
`docs/support.html` says a maiden-name registration is "a different athlete and there is no
way to merge the two automatically". The app has exactly that feature (Settings, "Find another
registered name", `LockerStore.addContact`), and the site's own index page advertises it.
Point support readers at the in-app path.

### 12.3 "No analytics" vs RevenueCat attributes (P1, compliance)
The privacy policy and the site say "no analytics SDK" and that RevenueCat receives only "an
anonymous app user ID, transaction and entitlement information, and limited technical
context". `ConversionDiagnostics.subscriberAttributes` is synced to RevenueCat through
`StoreService.syncConversionAttributes()` on every paywall impression and purchase. It includes
app-open counts, install and first-seen dates, and paywall views by surface. That is product
interaction data. It is not tracking, but the policy and the App Privacy labels should say so
("usage counts related to purchase screens, linked to an anonymous ID"). Otherwise a reviewer,
or a user reading the RevenueCat dashboard export, finds a mismatch.

### 12.4 Credentials exist, just not in the app (P2)
The site says "Sixteen full distance finishes and a lot of race mornings". That line belongs in
the app's Tips hero (see 8.2).

### 12.5 Content counts drift (P2)
The site says "Nineteen filmed tips/pointers". `PointersView`'s doc comment says "twenty
clips", and `.claude/rules/pointers-and-pattie.md` counts 56 voice clips. Take the count from
`pointers.json` at build time, or drop the number from the copy.

---

## 13. Accessibility and type

### 13.1 Contrast (P1)
WCAG contrast ratios computed from the `TriPalette` values:

| Pair | Ratio | Used for | Verdict (small text needs 4.5) |
| --- | --- | --- | --- |
| `inkTertiary` on `surface`, light | 4.45 | captions, metadata, subtitles on cards | fails, just barely |
| `inkTertiary` on `canvas`, light | 4.01 | footnotes on the canvas (Race Book disclaimer, legends) | fails |
| `inkTertiary` on `surface`, dark | 4.68 | same | passes |
| `positive` on `surface`, light | 4.29 | "Race Book unlocked", "faster" deltas | fails |
| white on `sunrise`, dark | 3.18 | PB badges (11pt), primary buttons | fails for badges; buttons pass only as large bold text |
| white on `sunrise`, light | 5.34 | same | passes |

`inkTertiary` is the most-used secondary colour in the app, at 11 to 13pt. Darken light-mode
`inkTertiary` to about (0.40, 0.43, 0.48) and `positive` slightly. In dark mode, use `ink` or a
dark label on `sunrise` badges, or darken `sunrise` for fills while keeping the lighter value
for text.

### 13.2 Dynamic Type (good, with gaps)
`TriType` is built on text styles, so it scales. The gaps are:
- The custom tab bar clamps labels to `.xSmall ... .large` (9.5).
- `StatTile` captions are `lineLimit(1)` with `minimumScaleFactor(0.78)` inside non-scrolling
  `HStack`s in Explore (7.5) and the race detail hero.
- Icons use fixed `.system(size:)` and do not scale with text.

### 13.3 VoiceOver (P2)
- `RaceRow` is not combined, so VoiceOver steps through race name, date, badge, bib, time, age
  group, split bar and each PB badge separately. That is eight or more swipes per race in a
  list of dozens. Give the row
  `.accessibilityElement(children: .combine)` plus a composed label ("IRONMAN Wisconsin,
  September 7 2025, 8 hours 36 minutes, 1st M25-29, personal best finish and swim").
- Times are read as "8:36:16" (VoiceOver says "eight thirty-six sixteen"). Provide
  `accessibilityLabel`s built with `Duration.formatted(.units(...))`.
- `StatTile`s in the headers read the value and caption separately. Combine them.

### 13.4 Numbers in SF Mono (P2)
The `stat*` styles use `design: .monospaced` (SF Mono) as well as `.monospacedDigit()`. DESIGN.md
§1 says SF Pro with monospaced digits. SF Mono makes every time in the app look like terminal
output, which is exactly the "vibe coded" tell to avoid. `.monospacedDigit()` on SF Pro already
stops columns from jumping. Drop `design: .monospaced`.

---

## 14. Still worth checking on a device

CoreSimulator was hung during this audit, so these need a real render:
1. The swipe-back test on a race detail (4.1).
2. Whether the Pattie pet covers the Locker tab and steals its taps (10.4).
3. The "Racing since" year on an Explore profile (7.1).
4. Paywall scrolling under the close button (6.6).
5. Explore header and race detail stat tiles at the largest accessibility text size (7.5,
   13.2).
6. Pattie Mode on a phone with the Silent switch on (10.1).
7. A Race Book PDF for a long name and for an athlete with DNFs (11.2, 11.3).
8. Fresh App Store captures of the shipping UI to replace the stale set (1.2).
