# IM Iron Splits customer experience audit

Audit date: 2026-09-26

## Scope and evidence

This is a source and artifact review of the current local working tree. I reviewed the onboarding and search path, Locker, Explore, race details, Race Book and purchase flow, Settings, Pattie and the episode library, accessibility primitives, the privacy and support pages, and the checked-in App Store capture inputs.

I did not change app code, configuration, screenshots, or metadata. I did not build or run the app, run tests, inspect the live App Store listing, or inspect a live RevenueCat account. Findings about behavior are either directly visible in source or explicitly labeled as a source-level inference. Static color ratios below were calculated from the sRGB values in TriDesign.swift. They should be checked in the rendered app as well.

The checkout already contained unrelated modified and deleted files when this review began. They were left untouched. The local screenshot capture report identifies a different source commit from the current checkout, so those images are treated as stale artifacts, not as proof of the currently running app.

Priority meanings:

- P1: likely to damage first-use success, user trust, accessibility, or purchase clarity.
- P2: meaningful friction or a common edge case, with a usable path still available.
- P3: polish or a narrower preference issue.

## Executive assessment

The core experience has a strong foundation. A new athlete can get to a real race history without making an account, cached results remain useful offline, race kinds are compared separately, the full result history stays free, and race notes and exports are local. Search explains that it has a slower second pass. The field lookup is separate from the athlete's own result, and Settings has useful controls for units, appearance, data removal, purchases, and downloaded episodes. Pattie Mode is opt-in.

The main opportunities are to make first use safer and more predictable, state the results coverage precisely, improve accessibility contrast, and put free value ahead of export configuration. The most consequential source issues are:

1. Old search results stay selectable while a new name is being searched.
2. Onboarding promises every finished race although the app only displays full and half-distance triathlon results from one feed.
3. Some small text and filled badges fall short of normal-text contrast in one or both appearance modes.
4. The local submission screenshot pipeline still includes the old Bests tab, while the current app has Explore, Tips, and Race Book.
5. Paywall copy describes personal-best and progression views as paid features even though the app presents those views for free.

## Findings

### CX-001 | P1 | Search can claim someone from the previous query

When a user has results for one name and starts another search with at least three characters, the old result rows remain on screen while the new request runs. AthleteSearchView changes the phase to quick search but does not clear matches in runSearch(for:). The results builder shows the list whenever matches is nonempty, so those rows remain tappable and look like results for the text currently in the field. A prefix search can be quick, but the substring fallback can take much longer.

Evidence: AthleteSearchView.swift:80-89, 204-218, 252-278. The row action immediately claims the selected athlete at 285-305.

Customer impact: a user can type a new name, tap a visible row from the previous name, and replace their Locker with the wrong public record. The longer the new query takes, the more likely the mismatch is.

Recommendation: clear the prior matches as soon as a new query starts, or visibly label them as previous results and disable selection until the new query completes. The safest behavior is to show the loading state whenever a new query is active, even if a previous query had results.

### CX-002 | P1 | First-run copy overpromises result coverage

The onboarding introduction says every race the athlete has finished is already published and promises that the Locker will fill in with all of them. The app filters supported results to full-distance and half-distance triathlon only. Other running and triathlon results from the same feed are not displayed. The no-results state tells users to retry the registered name, but does not say which race types are covered or that a valid athlete can still have no supported result.

Evidence: AthleteSearchView.swift:104-109 and 314-321; RaceResult.swift:174-181; ResultsAPI.swift:104-109 and 126-129. The support page states the narrower coverage at support.html:39-44, but a new user has to leave the app to find that qualification.

Customer impact: a marathoner, trail racer, or athlete whose only published results are unsupported can follow the instructions correctly and still reach an empty Locker. The current copy makes this feel like a search failure or a missing career, rather than a coverage limit.

Recommendation: promise published full and half-distance triathlon results from the supported timing feed. In the no-results state, explain the supported coverage, suggest trying the exact registered name or another registration, and link to the existing support explanation. Keep missing recent results distinct from results that the app does not support.

### CX-003 | P1 | The slow search state understates the wait and hides recovery

After the prefix pass finds nothing, the UI says it is searching the whole index, “which takes a moment.” The repository documents the substring request as a full scan that can take around thirty seconds. ResultsAPI allows a 60-second timeout for substring requests. The user can clear or edit the field, but that also changes the query; there is no clear Stop action, elapsed time, or direct explanation of what to do if the broad search still finds nothing.

Evidence: AthleteSearchView.swift:133-146, 202-218, 239-249; ResultsAPI.swift:74-85 and 218-228. The automatic search begins at three characters while manual submit accepts two, so the minimum is also not consistent across the two paths.

Customer impact: a user who sees no response for tens of seconds may assume the app is frozen or abandon onboarding. “A moment” sets a shorter expectation than the actual slow path. A recoverable search feels like a failed one when the user cannot tell what is happening or whether their entered name has been retained.

Recommendation: name the slow phase accurately, give a realistic wait expectation, keep the term visible, and offer an explicit way to stop it. On completion, suggest the next useful action: try the full legal first name, surname-first order, another registration, or the official result page. Align automatic and manual minimum lengths.

### CX-004 | P2 | Explain the name lookup before it leaves the device

The search request contains the entered name and is sent through the configured third-party results proxy. Looking up the Locker later sends official contact identifiers; opening a race sends its event identifier. The privacy policy does disclose this under “Requests to published results,” and it also says notes are not uploaded. The search screen itself only says “official results feed,” so the user has to open the policy to learn that the typed name is sent to the service.

Evidence: ResultsAPI.swift:74-85, 96-109, 113-117; AthleteSearchView.swift:221-237 and 314-321; docs/privacy-policy.html:41-48.

Customer impact: the first action asks for a personal name and immediately performs a network search. Even when the request is expected, the user should not have to infer which data is sent or who receives it.

Recommendation: add a short, calm note beside the search field or onboarding introduction: name searches go to the event results service, no account is created, and race notes stay on this phone. Link to the existing privacy policy for details. Keep this wording consistent with the actual request path.

### CX-005 | P1 | Small text and badges have low contrast

The palette is scheme-aware, which is a good foundation, but several token pairs are weak for the text sizes that use them. Using the source sRGB values and the WCAG relative-luminance formula:

- Light inkTertiary against the canvas is approximately 4.01:1. Against a white surface it is about 4.45:1.
- White text against the dark-mode sunrise accent is approximately 3.18:1. Filled PB badges use the micro font over sunrise.

Normal text below 18pt, or below 14pt when bold, generally needs 4.5:1 contrast under WCAG AA ([W3C, WCAG 2.2 Success Criterion 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)). The 11pt filled badge text does not meet that level in dark mode. Tertiary labels are also used for small captions and secondary metadata across the app.

Evidence: TriDesign.swift:20-55 defines the palette values; TriDesign.swift:391-414 defines TriBadge; Components.swift:98-105 uses a filled sunrise PB badge; TriDesign.swift:443-477 defines the primary button treatment.

Customer impact: users with low vision, glare, or a dim display may struggle to read precisely the secondary information that disambiguates race rows, settings, and statistics. Colorful badges can look polished while their text is hard to read.

Recommendation: raise tertiary text contrast on the light canvas and surface, and use a foreground appropriate to the bright dark-mode accent for small filled badges. Check text and icons separately in light and dark mode, especially the locker summary, race metadata, PB badges, paywall, and button labels.

### CX-006 | P1 | Store screenshot inputs describe an older tab layout

The current app tabs are Locker, Explore, Tips, Race Book, and Settings. The checked-in Locker capture visibly shows Locker, Bests, Pattie, Resume, and Settings. The screenshot manifest still includes a Bests screenshot as canonical submission evidence, and the capture script expects bests.png. The current ASCReleaseCaptureUITests capture Locker, race detail, Race Book, compare, export, Tips, and Settings, but do not capture Bests. The stored capture report was produced from commit 5326b1b; the current checkout is at 69b094d.

Evidence: RootTabView.swift:16-35 and 75-90; fastlane/asc-capture/race-book/locker.png; fastlane/asc-screenshots.json:55 and 219-233; scripts/capture-asc-screenshots.sh:35-45; IronSplitsUITests/ASCReleaseCaptureUITests.swift:15-72; fastlane/asc-capture/race-book/capture-report.json.

Customer impact: if these files are used for the submission, a prospective customer sees a navigation model that no longer exists in the app. A regenerated capture also cannot satisfy the current script's Bests attachment requirement. Both outcomes weaken the first impression and can create a mismatch between the purchased product and the screenshots.

Recommendation: update the screenshot source list, capture flow, report, and rendered submission set together from the current app. Replace the Bests proof with the current Race Book preview or Explore surface, depending on the story the screenshot is meant to prove. Confirm the actual ASC set separately, since the local repository cannot establish which images are currently live.

### CX-007 | P1 | Paywall lists free views as paid benefits

The paywall's shared feature list says the lifetime unlock includes a “Career personal-best and progression timeline.” The Race Book screen currently shows career summary, personal bests, and progression in its free preview. Settings and the support page also describe comparison and export as the paid boundary.

Evidence: PaywallView.swift:49-54; RaceBookView.swift:3-7, 73-99, 263-323; SettingsView.swift:109-120; docs/support.html:51-57.

Customer impact: users may think the preview is temporary or that these views will disappear unless they pay. A buyer may also feel that the paywall's description is inaccurate when they can already see those views. The same generic feature list appears for comparison and export triggers, so it is not tailored to the action the user chose.

Recommendation: list only the actual locked benefits: like-for-like race comparison and unlimited PDF or image export. When the paywall opens from one of those actions, lead with that action and describe exactly what becomes available. Keep the free preview visibly free.

### CX-008 | P2 | Race Book asks for export configuration before showing its free value

Race Book content starts with an export call to action and then an export-options card with ten toggles and distance controls. Career summary, personal bests, and progression follow those controls. Compare races is last in the long scroll. A free user can therefore encounter a purchase prompt and a sizable configuration form before seeing the main career insight.

Evidence: RaceBookView.swift:73-100; the order is intro, export, include options, career, distance, personal bests, progression, then compare.

Customer impact: the screen can feel like an export builder or upsell before it feels like a useful free results product. Users may miss the personal-best and progression value, and may spend time configuring an export they cannot create until they unlock Race Book.

Recommendation: show the free career overview, bests, and progression first. Put one contextual compare or export action after the user has seen a relevant result. Collapse the detailed export options until a user chooses to configure an export, and keep the locked action explicit.

### CX-009 | P2 | Explore race rows look like history but cannot be opened

Explore says users can see the story behind another racer's splits and browse their history. Its race history is rendered as plain RaceRow views, not buttons or navigation links. A racer can see the finish time, date, distance, and split bar, but cannot open that race to inspect official split times, ranks, or field context.

Evidence: ExploreView.swift:65-68, 268-282. ExploreAthleteView has a navigation destination for the athlete profile, but none for an individual result.

Customer impact: the feature introduces useful social and comparison intent, then stops at a summary row. A user who taps a race because they want the actual split story gets no response.

Recommendation: make each Explore race open a read-only race detail that reuses official splits and field context without changing the user's Locker or notes. If individual detail is intentionally out of scope, adjust the Explore promise and make the rows visibly noninteractive.

### CX-010 | P2 | Some field cards can stay on a spinner or appear empty

For a complete race with an empty eventID, RaceDetailView.loadField returns without changing fieldState. The field card remains in idle and displays “Loading the field…” forever. In the loaded state, placement rows are only drawn when a discipline has at least two valid finishers and a positive split. If none qualify, the card contains its heading and finisher count but no explanation.

Evidence: RaceDetailView.swift:147-202; RaceAnalytics.swift:111-123.

Customer impact: the user cannot tell whether the field is still loading, unavailable for this result, or empty. A spinner that never ends suggests the app is broken even though the athlete's own splits remain usable.

Recommendation: represent a missing event identifier as a completed unavailable state, not a loading state. Add a clear empty message when no discipline has enough comparable field data, and keep the user's own splits visible.

### CX-011 | P2 | Failed manual refreshes with cached data are silent

When a refresh fails and cached results already exist, LockerStore returns to loaded state. For most network or service errors it does not set refreshWarning. LockerView continues to show the timestamp of the last successful refresh, but gives no message that the most recent manual refresh failed.

Evidence: LockerStore.swift:101-143; LockerView.swift:82-103, 128-137, 197-200.

Customer impact: a user can pull to refresh and receive no indication that the data stayed stale. The old “Updated” time is available but is easy to overlook, especially if the refresh was meant to confirm a recent race or correct a discrepancy.

Recommendation: preserve the cached Locker, but show a quiet message after a failed user-requested refresh, such as “Could not update. Showing results last refreshed yesterday.” Keep automatic refresh failures less intrusive if needed.

### CX-012 | P2 | First claim can start two career requests

There is a source-level path to duplicate network work on first claim. LockerStore.claim sets athlete and then awaits refresh(force: true). RootTabView switches to tabs as soon as hasClaimedAthlete becomes true, and the tabs task also calls locker.refresh(). That second refresh has no in-flight guard, starts a newer generation, and can make the first response obsolete while both requests are still running.

Evidence: LockerStore.swift:56-63 and 106-143; RootTabView.swift:40-55 and 75-104.

Customer impact: the first load can use two results requests, waste the user's network time, and do unnecessary work against the external timing service. The generation check protects which response is applied, but it does not prevent the duplicate request.

Recommendation: make refresh single-flight for the same contact IDs, or have the tab task skip refresh while the claim's first load is already in progress. Confirm the interleaving in a runtime trace before changing behavior.

### CX-013 | P2 | A DNF or repeated race open can count as a positive moment

RaceDetailView records a positive moment before checking whether the result is complete. It records again whenever the same detail task runs. RootTabView can present the enjoyment sheet after a pending positive moment reaches the configured thresholds. Opening a DNF can therefore satisfy a positive moment and may trigger a review prompt at an emotionally poor time.

Evidence: RaceDetailView.swift:46-57; RootTabView.swift:61-67 and 151-156; ReviewPromptTracker.swift:121-132 and 163-187.

Customer impact: a review prompt can interrupt a user inspecting a difficult result or a DNF, and repeat opens can make the app ask for a review based on navigation rather than genuine satisfaction.

Recommendation: count deliberate positive outcomes, such as a successful first Locker load or a newly identified personal best, and avoid counting the same result repeatedly. Do not raise a rating prompt after a failure or incomplete race.

### CX-014 | P2 | “Send feedback” only opens a draft and records it as submitted

ReviewPromptSheet labels the button “Send feedback,” but its action opens a mailto draft. It marks the feedback submitted and dismisses the sheet immediately, without checking whether the email app opened or whether the user sent the message.

Evidence: ReviewPromptSheet.swift:191-216 and 219-277; ReviewPromptTracker.swift:195-203.

Customer impact: a user can believe feedback was sent when they only opened or dismissed a draft. If no suitable mail app is available, the text is discarded when the sheet closes. The stored outcome also treats draft creation as completed feedback.

Recommendation: label the action honestly, for example “Continue in email,” and only record that the user opened a draft. Preserve the entered text or offer a copyable fallback if opening mail fails. Distinguish feedback started from feedback actually sent.

### CX-015 | P2 | The custom tab labels stop scaling at Large text

The app hides the system tab bar and draws its own. The custom tab labels explicitly limit Dynamic Type to xSmall through Large, keep every label on one line, and allow text to shrink to 80 percent. Users who choose larger accessibility text cannot enlarge the tab names.

Evidence: RootTabView.swift:75-95 and 106-134, especially the Dynamic Type clamp at 116-121.

Customer impact: the five primary navigation controls are always present, so small tab labels can make the whole app harder to navigate for users who rely on larger text. Other TriType styles use semantic system font styles and can scale; the tab bar is a specific exception.

Recommendation: allow accessibility sizes and adapt the bar layout when labels no longer fit. Check the selected state and hit targets with VoiceOver and the largest supported text sizes.

### CX-016 | P2 | Pattie's larger reactions can disappear before the user finishes reading

Pattie Mode is opt-in, which is good. Once enabled, the companion automatically dismisses ordinary messages after roughly two to four seconds, and larger catchphrase takeovers after roughly three to five seconds, unless a voice clip is still playing. The timer does not check whether VoiceOver is reading the text. Reduce Motion removes animation but does not change this timeout.

Evidence: PattiePopup.swift:230-260 and 267-285.

Customer impact: users who need more time to read, or who use VoiceOver, may lose a useful tip before finishing it. The full-screen catchphrase also covers the content beneath it, so the short timeout is especially consequential.

Recommendation: keep an explicit dismiss action, which already exists, but make automatic dismissal respect VoiceOver and give longer content enough reading time. Consider leaving the larger message visible until the user dismisses it.

### CX-017 | P2 | App identity differs between the project guide and customer copy

The repo guide identifies the app as IM Iron Splits. The checked-in App Store metadata, website, Settings disclaimer, and review sheet use IM Tri Tracker. This audit treats the repo guide as the canonical app name and does not revisit the name decision itself.

Evidence: CLAUDE.md:1-5; fastlane/metadata/en-US/name.txt:1; SettingsView.swift:95 and 166; ReviewPromptSheet.swift:106-127 and 153-163; docs/index.html:6-25.

Customer impact: users can see one name in the store and another in Settings, feedback prompts, or other touchpoints. This can look like a different app or an unannounced rename, and makes it harder to recognize support and policy pages.

Recommendation: use the canonical name consistently in in-app copy, support, website, and store metadata. Treat old-name occurrences as deliberate legacy compatibility only where they must remain.

### CX-018 | P3 | Race notes show US-only example units

The conditions placeholder uses “Water 68°F, 15mph crosswind” for everyone, while Settings exposes a distance and pace unit preference. It is only example copy, but it presents two region-specific units as the expected format.

Evidence: RaceDetailView.swift:351-367; SettingsView.swift:73-83.

Customer impact: metric users may wonder whether the note field or race statistics assume US units.

Recommendation: use a unit-neutral example, such as “Water temperature and wind on the bike course,” or format the example using the user's unit preference.

### CX-019 | P3 | Distance filters reset after the app is recreated

Locker and Race Book keep selected distance in view-local state. AppSettings already has a stored preferredKind with a comment saying it should reopen where the athlete left it, but the screens do not read or write that setting. The Locker resets to All; Race Book selects the most-raced distance.

Evidence: AppSettings.swift:32-52; LockerView.swift:9-10 and 173-189; RaceBookView.swift:17-18 and 529-551.

Customer impact: multi-distance athletes may have to reselect their preferred distance after relaunching or when a screen is recreated.

Recommendation: either connect the saved preference to the filters that benefit from it, or remove the unused preference and set the reset behavior deliberately. Keep an All option where users need a complete history.

## Recommended order

1. Fix the stale search result selection, then tighten first-run coverage copy and make the slow-search state honest.
2. Correct the accessibility contrast pairs and verify the custom tab bar at accessibility text sizes.
3. Align the local App Store capture inputs, capture script, and generated assets with the current five-tab app.
4. Make the paid boundary accurate in every paywall trigger, then move free Race Book value above export configuration.
5. Add explicit field and refresh failure states, and guard the first claim against duplicate refresh work.
6. Improve the review prompt and mail feedback flow so they follow real positive outcomes and give users a reliable way to send feedback.
7. Resolve the canonical name in customer-facing copy, then address the narrower Pattie, unit-example, and filter-persistence details.

## Verification plan for a later implementation pass

This audit did not run the app or tests. Before implementing or marking the findings closed, validate:

- Search a successful name, then immediately type a different name. Confirm no old result can be selected while the second query is active.
- Test no results, a slow substring search, cancellation, timeout, and retry while preserving the query.
- Claim an athlete with full and half-distance results, one with no supported result, and one whose results use another registered name.
- Open complete races with missing event IDs, one or zero valid field finishers, and a field request failure.
- Pull to refresh with cached results while offline and confirm the last successful data remains available with a clear freshness message.
- Compare Light and Dark contrast for small metadata, filled PB badges, buttons, and the Race Book paywall.
- Use VoiceOver and accessibility text sizes on the custom tab bar, Pattie bubbles, the feedback sheet, and Race Book controls.
- Regenerate the local App Store screenshot set from the current source and confirm all captures match current tab labels and the actual free versus paid boundary.
- Open feedback on a device with and without a configured mail client; confirm the copy, entered text, and recorded outcome match what actually happened.
