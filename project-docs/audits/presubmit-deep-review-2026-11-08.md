# Pre-submit deep review, 2026-11-08

Version under review: 1.1.5 (build 41) on `origin/main` at `9bf20e8`. Live version: 1.1.4 (build 40, `ceddec7`). App sources (`IronSplits/`, `Shared/`) did not change between the two, so this pass covers the whole app, not the diff. The diff-only review is `presubmit-review-2026-11-07.md`.

## Scope

Every path a user can reach on the current tree:

- Purchase, restore and the paywall: `StoreService`, `PaywallView`, `PlanOption`, `ProGate`, and the Race Book gate call sites.
- Onboarding and athlete claim: `RootTabView`, `AthleteSearchView`, `LockerStore`.
- Persistence: the Locker snapshot, race notes, settings, feed config, the pointer catalog, the Ask Pattie guide, the race field cache, and Explore recents.
- Feed transport: `ResultsAPI`, `ODataResultRow`, `FeedConfig`.
- Race detail, Race Book, and PDF and image export.
- Tips: Ask Pattie, the episode library and its downloads, Pattie Mode and voice.
- The review prompt and the iPhone Duo panes.

The app has no widgets, app intents, notifications, SwiftData or Core Data. It is English only, with no string catalogs.

Clean:

- Every saved model either has a tolerant decoder or has kept the same schema since 1.0. This covers `Athlete`, `RaceResult` and `RaceNote`.
- `ProGate.everythingUnlocked` is `false`, and every paid action checks `raceBookUnlocked(isPro:)`.
- The paywall can always be closed and closes itself on purchase.
- The paywall has Restore, Terms and Privacy, and prices come from StoreKit.
- RevenueCat delivers cached `CustomerInfo` through the delegate, so a paid user offline still unlocks.
- All array subscripts are guarded.
- Debug paths are inside `#if DEBUG`.
- No health claims, other-platform links or hard-coded prices.

## Findings

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P1 | Shared/Models/Pointer.swift:107 | Leaving All episodes before the catalog loads cancels the fetch. The cancellation was stamped as a failed attempt, so for 12 hours the tab showed "Couldn't load episodes" with an empty list until the user tapped Try again. | Fixed: a cancelled fetch returns without stamping. Test `CancelledFetchTests.testCancelledPointerFetchDoesNotStampAttempt` |
| P1 | IronSplits/Views/AskPattieView.swift:261 | Answer cards read only the cached episode catalog. On a fresh install, where Tips opens on Ask Pattie, the "Full clip" button never appeared until All episodes had been opened once. | Fixed: the card falls back to the throttled `refresh()` when the cache is empty. View code, so no unit test |
| P1 | Shared/Services/PattieVoice.swift:30 | A phone call or Siri during a clip pauses the player without a finish callback. `nowPlaying` stayed set, so Pattie Mode went silent for the rest of the session and the answer's play control stayed on Stop. | Fixed: observe `AVAudioSession.interruptionNotification` and stop on `.began`. Test `testAudioInterruptionClearsSpeakingState` |
| P2 | Shared/Models/AskPattie.swift:168 | The same cancelled-fetch stamping held off a newer hosted guide for 12 hours. The bundled guide still showed. | Fixed with the same guard. Test `testCancelledAskPattieFetchDoesNotStampAttempt` |
| P2 | Shared/Services/ResultsFeed.swift:154 | The same stamping on the feed hotfix channel: closing the search screen mid-fetch delayed a new `api-config.json` for 6 hours. | Fixed with the same guard. No unit test, because the test host's own launch-time fetch races it |
| P2 | Shared/Services/LockerStore.swift:122 | Re-claiming the same athlete while a refresh of those contact ids is still in flight returns early. The in-flight response is then discarded by the generation check, which leaves the Locker on "Pulling your results" until relaunch. It needs a re-pick within the same second or two. | Not fixed: rare timing, and a relaunch recovers from disk |
| P2 | Shared/Services/LockerStore.swift:68 | A replacement claim that fails on the network keeps the previous athlete's snapshot on disk, so a relaunch shows the old athlete again. | Not fixed: arguably the safer outcome, and no data is lost |
| P2 | IronSplits/Views/PaywallView.swift:498 | A purchase error shows `store.lastError`, which can be a stale customer-info refresh message rather than the purchase failure. | Not fixed: copy only, and the purchase path itself works |
| P2 | Shared/Models/Pointer.swift:25 | `isFree` has a default but no tolerant decoder, so a hosted episode published without the key fails the whole catalog decode. | Not fixed: today's `docs/pointers.json` is valid. Content rule |
| P2 | Shared/Services/PointerMedia.swift:79 | Reopening an episode whose download is already in flight shows no percentage until it finishes. | Not fixed: cosmetic |
| P2 | Shared/Services/RaceBookPDFRenderer.swift:602 | A single race note over about 4,500 characters draws past the bottom of a PDF page. | Not fixed: extreme input only |
| P2 | docs/ask-pattie.json (goal `half`) | The goal title "A 70.3" uses distance shorthand that AGENTS.md keeps out of branding. | Not fixed: content, regenerate with `scripts/build-ask-pattie.py` if wanted |
| P2 | IronSplits/Views/RootTabView.swift:70 | Unfolded on the iPhone Duo during onboarding, the trailing pane shows "Pick a race in your Locker" before any athlete is claimed. | Not fixed: design call |

No P0 findings. No P1 findings are open.

## Tests

See the commit that adds this report for the gh-sim run id and result.
