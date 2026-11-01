# Release gate: ironman-ship 8dac85abf5b7

Verdict: **BLOCK** (2026-11-01T11:02:44+00:00)

Every finding blocks except legacy backlog. `qa-gate fix <repo>` fixes them. Motion candidates need a judgement in the ledger: `qa-gate ledger <repo> accept` for an intended change, or `add` a P1 when it is a real glitch.

## Blocking (29)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P1 | error-state | newcomer | testCoreLoopLockerRaceSurvivesRelaunch / race-detail-after-relaunch | the screen shows a failure: "Couldn't load the field. Try again." | `error-state|testCoreLoopLockerRaceSurvivesRelaunch|race-detail-after-relaunch|couldn't load the field. try again.` |
| P1 | overlap | duo | test01FirstRunClaimsAnAthlete / first-locker | button "IRONMAN World Championship, Oct 10, 2026, 9 hours, 8 minutes, 36 seconds, 21st in M25-29" overlaps "Locker" by 32% | `overlap|test01FirstRunClaimsAnAthlete|first-locker|ironman world championship, oct #, #, # hours, # minutes, # ` |
| P1 | overlap | duo | test01FirstRunClaimsAnAthlete / first-locker | button "IRONMAN World Championship, Oct 10, 2026, 9 hours, 8 minutes, 36 seconds, 21st in M25-29" overlaps "Explore" by 39% | `overlap|test01FirstRunClaimsAnAthlete|first-locker|explore / ironman world championship, oct #, #, # hours, # m` |
| P1 | clipped | duo | test02LockerRaceAndRankings / rankings | button drawn as "T1+" but reads "T1+T2", cut off with no ellipsis | `clipped|test02LockerRaceAndRankings|rankings|t#+t#` |
| P0 | journey-broken | newcomer | test02LockerRaceAndRankings /  | Failed to get matching snapshot: No matches found for first query match sequence: `Descendants matching type CollectionView`, given input App element pid: 19696 | `journey-broken|test02LockerRaceAndRankings` |
| P0 | journey-broken | accessibility | test02LockerRaceAndRankings /  | Failed to get matching snapshot: No matches found for first query match sequence: `Descendants matching type CollectionView`, given input App element pid: 22263 | `journey-broken|test02LockerRaceAndRankings` |
| P0 | journey-broken | reduce-motion | test02LockerRaceAndRankings /  | Failed to get matching snapshot: No matches found for first query match sequence: `Descendants matching type CollectionView`, given input App element pid: 25498 | `journey-broken|test02LockerRaceAndRankings` |
| P2 | a11y-contrast | newcomer | test02LockerRaceAndRankings / race-detail | Contrast failed: "37 finishers" | `a11y-contrast|test02LockerRaceAndRankings|race-detail|# finishers` |
| P2 | a11y-contrast | newcomer,reduce-motion | test02LockerRaceAndRankings / rankings | Contrast failed: "2024 · Full" | `a11y-contrast|test02LockerRaceAndRankings|rankings|# · full` |
| P2 | a11y-contrast | newcomer,reduce-motion | test02LockerRaceAndRankings / rankings | Contrast failed: "+13:08" | `a11y-contrast|test02LockerRaceAndRankings|rankings|+#:#` |
| P2 | a11y-contrast | newcomer,reduce-motion | test02LockerRaceAndRankings / rankings | Contrast failed: "T1+T2" | `a11y-contrast|test02LockerRaceAndRankings|rankings|t#+t#` |
| P2 | a11y-hit-region | duo | test01FirstRunClaimsAnAthlete / first-locker | Hit area is too small: "Swim 1 hour, 5 minutes, 15 seconds, T1 3 minutes, 41 seconds, Bike 4 hours, 43 minutes, 50 seconds, T2 4 minutes, 39 seconds, Run 3 hours, 11 minutes, 12 seconds" | `a11y-hit-region|test01FirstRunClaimsAnAthlete|first-locker|swim # hour, # minutes, # seconds, t# # minutes, # seconds, ` |
| P2 | a11y-hit-region | duo | test02LockerRaceAndRankings / locker | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test02LockerRaceAndRankings|locker|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region | accessibility,duo,newcomer,reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch / race-detail | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|testCoreLoopLockerRaceSurvivesRelaunch|race-detail|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-contrast | newcomer,reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch / race-detail | Contrast failed (measured 2.6:1): "DIVISION" | `a11y-contrast|testCoreLoopLockerRaceSurvivesRelaunch|race-detail|division` |
| P2 | a11y-contrast | newcomer,reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch / race-detail | Contrast failed (measured 2.6:1): "GENDER" | `a11y-contrast|testCoreLoopLockerRaceSurvivesRelaunch|race-detail|gender` |
| P2 | a11y-contrast | newcomer,reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch / race-detail | Contrast failed (measured 2.6:1): "OVERALL" | `a11y-contrast|testCoreLoopLockerRaceSurvivesRelaunch|race-detail|overall` |
| P2 | a11y-hit-region | accessibility,duo,newcomer,reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch / race-detail-after-relaunch | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|testCoreLoopLockerRaceSurvivesRelaunch|race-detail-after-relaunch|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-contrast | newcomer,reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch / race-detail-after-relaunch | Contrast failed (measured 2.6:1): "DIVISION" | `a11y-contrast|testCoreLoopLockerRaceSurvivesRelaunch|race-detail-after-relaunch|division` |
| P2 | a11y-contrast | newcomer,reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch / race-detail-after-relaunch | Contrast failed (measured 2.6:1): "GENDER" | `a11y-contrast|testCoreLoopLockerRaceSurvivesRelaunch|race-detail-after-relaunch|gender` |
| P2 | a11y-contrast | newcomer,reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch / race-detail-after-relaunch | Contrast failed (measured 2.6:1): "OVERALL" | `a11y-contrast|testCoreLoopLockerRaceSurvivesRelaunch|race-detail-after-relaunch|overall` |
| P2 | a11y-hit-region | duo | test02LockerRaceAndRankings / rankings | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test02LockerRaceAndRankings|rankings|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region | duo | test03RaceBookPaywallShownAndClosed / race-book | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test03RaceBookPaywallShownAndClosed|race-book|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region | duo | test03RaceBookPaywallShownAndClosed / race-book-after-paywall | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test03RaceBookPaywallShownAndClosed|race-book-after-paywall|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region | duo | test04ReturnVisitWithInterruption / explore | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test04ReturnVisitWithInterruption|explore|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region | duo | test04ReturnVisitWithInterruption / tips | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test04ReturnVisitWithInterruption|tips|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region | duo | test04ReturnVisitWithInterruption / settings | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test04ReturnVisitWithInterruption|settings|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region | duo | test04ReturnVisitWithInterruption / settings-after-interruption | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test04ReturnVisitWithInterruption|settings-after-interruption|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region | duo | test04ReturnVisitWithInterruption / locker-after-relaunch | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test04ReturnVisitWithInterruption|locker-after-relaunch|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |

## Needs a judgement (1)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P1 | motion-jump | newcomer | test03RaceBookPaywallShownAndClosed / race-book-paywall | jump candidate at 92.25s of journeys.mp4 (score 0.196) ([sheet](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/newcomer/journeys.event-06.png)) | `motion-jump|test03RaceBookPaywallShownAndClosed|race-book-paywall|` |

## Legacy backlog, warns until fixed (35)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P2 | a11y-contrast |  | test01FirstRunClaimsAnAthlete / first-locker | Contrast nearly passed (measured 3.5:1): "3" | `a11y-contrast|test01FirstRunClaimsAnAthlete|first-locker|#` |
| P2 | a11y-contrast |  | test01FirstRunClaimsAnAthlete / first-locker | Contrast failed (measured 2.6:1): "FINISHES" | `a11y-contrast|test01FirstRunClaimsAnAthlete|first-locker|finishes` |
| P2 | a11y-contrast |  | test01FirstRunClaimsAnAthlete / first-locker | Contrast failed (measured 2.6:1): "FULL" | `a11y-contrast|test01FirstRunClaimsAnAthlete|first-locker|full` |
| P2 | a11y-contrast |  | test01FirstRunClaimsAnAthlete / first-locker | Contrast failed (measured 2.6:1): "PODIUMS" | `a11y-contrast|test01FirstRunClaimsAnAthlete|first-locker|podiums` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / locker | Contrast nearly passed: "2025" | `a11y-contrast|test02LockerRaceAndRankings|locker|#` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / locker | Contrast failed (measured 2.6:1): "FINISHES" | `a11y-contrast|test02LockerRaceAndRankings|locker|finishes` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / locker | Contrast failed (measured 2.6:1): "FULL" | `a11y-contrast|test02LockerRaceAndRankings|locker|full` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / locker | Contrast failed (measured 2.6:1): "HALF" | `a11y-contrast|test02LockerRaceAndRankings|locker|half` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / locker | Contrast failed: "Half distance" | `a11y-contrast|test02LockerRaceAndRankings|locker|half distance` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / locker | Contrast failed: "Locker" | `a11y-contrast|test02LockerRaceAndRankings|locker|locker` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / locker | Contrast failed: "M40-44 #11" | `a11y-contrast|test02LockerRaceAndRankings|locker|m#-# ##` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / locker | Contrast failed: "Riverbend Triathlon" | `a11y-contrast|test02LockerRaceAndRankings|locker|riverbend triathlon` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / race-detail | Contrast failed: "Bike" | `a11y-contrast|test02LockerRaceAndRankings|race-detail|bike` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / race-detail | Contrast failed (measured 2.6:1): "DIVISION" | `a11y-contrast|test02LockerRaceAndRankings|race-detail|division` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / race-detail | Contrast failed (measured 2.6:1): "GENDER" | `a11y-contrast|test02LockerRaceAndRankings|race-detail|gender` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / race-detail | Contrast failed (measured 2.6:1): "OVERALL" | `a11y-contrast|test02LockerRaceAndRankings|race-detail|overall` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / race-detail | Contrast failed: "Riverbend Triathlon" | `a11y-contrast|test02LockerRaceAndRankings|race-detail|riverbend triathlon` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / rankings | Contrast nearly passed: "FINISHES" | `a11y-contrast|test02LockerRaceAndRankings|rankings|finishes` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / rankings | Contrast nearly passed: "FULL" | `a11y-contrast|test02LockerRaceAndRankings|rankings|full` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / rankings | Contrast nearly passed: "HALF" | `a11y-contrast|test02LockerRaceAndRankings|rankings|half` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / rankings | Contrast failed: "Locker" | `a11y-contrast|test02LockerRaceAndRankings|rankings|locker` |
| P2 | a11y-contrast |  | test02LockerRaceAndRankings / rankings | Contrast failed: "Run" | `a11y-contrast|test02LockerRaceAndRankings|rankings|run` |
| P2 | a11y-contrast |  | test04ReturnVisitWithInterruption / locker-after-relaunch | Contrast failed (measured 2.6:1): "FINISHES" | `a11y-contrast|test04ReturnVisitWithInterruption|locker-after-relaunch|finishes` |
| P2 | a11y-contrast |  | test04ReturnVisitWithInterruption / locker-after-relaunch | Contrast failed (measured 2.6:1): "FULL" | `a11y-contrast|test04ReturnVisitWithInterruption|locker-after-relaunch|full` |
| P2 | a11y-contrast |  | test04ReturnVisitWithInterruption / locker-after-relaunch | Contrast failed (measured 2.6:1): "HALF" | `a11y-contrast|test04ReturnVisitWithInterruption|locker-after-relaunch|half` |
| P2 | a11y-contrast |  | test04ReturnVisitWithInterruption / tips | Contrast nearly passed (measured 3.6:1): "PATTIE WALLNER" | `a11y-contrast|test04ReturnVisitWithInterruption|tips|pattie wallner` |
| P2 | a11y-hit-region |  | test01FirstRunClaimsAnAthlete / claim-search | Hit area is too small: "Privacy details" | `a11y-hit-region|test01FirstRunClaimsAnAthlete|claim-search|privacy details` |
| P2 | a11y-hit-region |  | test02LockerRaceAndRankings / race-detail | Hit area is too small: "Swim 59 minutes, 50 seconds, T1 4 minutes, 42 seconds, Bike 5 hours, 8 minutes, 20 seconds, T2 3 minutes, 20 seconds, Run 3 hours, 55 minutes" | `a11y-hit-region|test02LockerRaceAndRankings|race-detail|swim # minutes, # seconds, t# # minutes, # seconds, bike # h` |
| P2 | a11y-hit-region |  | test03RaceBookPaywallShownAndClosed / race-book-paywall | Hit area is too small: "Privacy" | `a11y-hit-region|test03RaceBookPaywallShownAndClosed|race-book-paywall|privacy` |
| P2 | a11y-hit-region |  | test03RaceBookPaywallShownAndClosed / race-book-paywall | Hit area is too small: "Restore Purchases" | `a11y-hit-region|test03RaceBookPaywallShownAndClosed|race-book-paywall|restore purchases` |
| P2 | a11y-hit-region |  | test03RaceBookPaywallShownAndClosed / race-book-paywall | Hit area is too small: "Terms" | `a11y-hit-region|test03RaceBookPaywallShownAndClosed|race-book-paywall|terms` |
| P2 | clipped |  | test02LockerRaceAndRankings / race-detail | button "Settings" is broken across 2 lines: * / Settings (AX3 text only) | `clipped|test02LockerRaceAndRankings|race-detail|gearshape.fill` |
| P2 | reduce-motion-ignored |  | all / all | with Reduce Motion on the journeys still moved for 61.3s against 38.1s without it (161%); check which animations ignore it | `reduce-motion-ignored|all|all|` |
| P3 | a11y-element-description |  | test01FirstRunClaimsAnAthlete / claim-results | Element has no description | `a11y-element-description|test01FirstRunClaimsAnAthlete|claim-results|` |
| P3 | a11y-element-description |  | test03RaceBookPaywallShownAndClosed / race-book-paywall | Label not human-readable: "$9.99" | `a11y-element-description|test03RaceBookPaywallShownAndClosed|race-book-paywall|$#` |

## Journeys

| Persona | Journey | Result | Seconds |
|---|---|---|---|
| newcomer | test01FirstRunClaimsAnAthlete | Passed | 29.30463993549347 |
| newcomer | test02LockerRaceAndRankings | Failed | 24.920338988304138 |
| newcomer | test03RaceBookPaywallShownAndClosed | Passed | 39.25224304199219 |
| newcomer | test04ReturnVisitWithInterruption | Passed | 61.44682705402374 |
| newcomer | testCoreLoopLockerRaceSurvivesRelaunch | Passed | 31.971058011054993 |
| accessibility | test01FirstRunClaimsAnAthlete | Passed | 25.53954291343689 |
| accessibility | test02LockerRaceAndRankings | Failed | 23.74466907978058 |
| accessibility | test03RaceBookPaywallShownAndClosed | Passed | 47.99920392036438 |
| accessibility | test04ReturnVisitWithInterruption | Passed | 58.98898792266846 |
| accessibility | testCoreLoopLockerRaceSurvivesRelaunch | Passed | 30.917760968208313 |
| reduce-motion | test01FirstRunClaimsAnAthlete | Passed | 60.09819197654724 |
| reduce-motion | test02LockerRaceAndRankings | Failed | 25.67052698135376 |
| reduce-motion | test03RaceBookPaywallShownAndClosed | Passed | 39.06710600852966 |
| reduce-motion | test04ReturnVisitWithInterruption | Passed | 62.993985056877136 |
| reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch | Passed | 35.67606794834137 |
| duo | test01FirstRunClaimsAnAthlete | Passed | 30.172644019126892 |
| duo | test02LockerRaceAndRankings | Passed | 29.43739604949951 |
| duo | test03RaceBookPaywallShownAndClosed | Passed | 44.23188102245331 |
| duo | test04ReturnVisitWithInterruption | Passed | 63.71405506134033 |
| duo | testCoreLoopLockerRaceSurvivesRelaunch | Passed | 30.15155792236328 |

## Motion

| Persona | Motion s | Windows | Candidates | Gaps > 25 ms | 60 fps |
|---|---|---|---|---|---|
| newcomer | 38.063 | 45 | 23 | 145 | True |
| accessibility | 39.848 | 50 | 8 | 140 | True |
| reduce-motion | 61.341 | 71 | 16 | 612 | True |

## Launch entrances to look at

Each launch's frames after the springboard zoom, left to right then down, 4 frames per
row at the recorded rate. A blank stretch, text that reflows, or content that arrives and
pushes the layout is a finding: `qa-gate ledger <repo> add`.

- [entrance-01-test01firstrunclaimsanathlete.png](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/newcomer/entrance-01-test01firstrunclaimsanathlete.png)
- [entrance-05-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/newcomer/entrance-05-launchseeded.png)
- [entrance-08-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/newcomer/entrance-08-launchseeded.png)
- [entrance-01-test01firstrunclaimsanathlete.png](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/accessibility/entrance-01-test01firstrunclaimsanathlete.png)
- [entrance-05-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/accessibility/entrance-05-launchseeded.png)
- [entrance-08-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/accessibility/entrance-08-launchseeded.png)
- [entrance-18-test04returnvisitwithinterruption.png](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/accessibility/entrance-18-test04returnvisitwithinterruption.png)
- [entrance-01-test01firstrunclaimsanathlete.png](/Users/jackwallner/ironman-ship/build/qa/8dac85abf5b7/reduce-motion/entrance-01-test01firstrunclaimsanathlete.png)

Skipped personas: german (app not localized).
