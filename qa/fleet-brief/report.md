# Release gate: ironman-ship 4e259be6d1ff

Verdict: **BLOCK** (2026-11-01T18:00:36+00:00)

Every finding blocks except legacy backlog. `qa-gate fix <repo>` fixes them. Motion candidates need a judgement in the ledger: `qa-gate ledger <repo> accept` for an intended change, or `add` a P1 when it is a real glitch.

## Blocking (4)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P1 | overlap | duo | test01FirstRunClaimsAnAthlete / first-locker | button "IRONMAN World Championship, Oct 10, 2026, 9 hours, 8 minutes, 36 seconds, 21st in M25-29" overlaps "Locker" by 32% | `overlap|test01FirstRunClaimsAnAthlete|first-locker|ironman world championship, oct #, #, # hours, # minutes, # ` |
| P1 | overlap | duo | test01FirstRunClaimsAnAthlete / first-locker | button "IRONMAN World Championship, Oct 10, 2026, 9 hours, 8 minutes, 36 seconds, 21st in M25-29" overlaps "Explore" by 39% | `overlap|test01FirstRunClaimsAnAthlete|first-locker|explore / ironman world championship, oct #, #, # hours, # m` |
| P2 | clipped | accessibility | testCoreLoopLockerRaceSurvivesRelaunch / race-detail | button "Settings" is broken across 2 lines: * / Settings (AX3 text only) | `clipped|testCoreLoopLockerRaceSurvivesRelaunch|race-detail|gearshape.fill` |
| P2 | clipped | accessibility | testCoreLoopLockerRaceSurvivesRelaunch / race-detail-after-relaunch | button "Settings" is broken across 2 lines: * / Settings (AX3 text only) | `clipped|testCoreLoopLockerRaceSurvivesRelaunch|race-detail-after-relaunch|gearshape.fill` |

## Needs a judgement (1)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P1 | motion-jump | newcomer | test02LockerRaceAndRankings / race-detail | jump candidate at 51.68s of journeys.mp4 (score 0.144) ([sheet](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/newcomer/journeys.event-04.png)) | `motion-jump|test02LockerRaceAndRankings|race-detail|` |

## Legacy backlog, warns until fixed (10)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P2 | a11y-contrast |  | test01FirstRunClaimsAnAthlete / first-locker | Contrast nearly passed (measured 3.5:1): "3" | `a11y-contrast|test01FirstRunClaimsAnAthlete|first-locker|#` |
| P2 | a11y-contrast |  | test04ReturnVisitWithInterruption / tips | Contrast nearly passed (measured 3.6:1): "PATTIE WALLNER" | `a11y-contrast|test04ReturnVisitWithInterruption|tips|pattie wallner` |
| P2 | a11y-hit-region |  | test01FirstRunClaimsAnAthlete / claim-search | Hit area is too small: "Privacy details" | `a11y-hit-region|test01FirstRunClaimsAnAthlete|claim-search|privacy details` |
| P2 | a11y-hit-region |  | test03RaceBookPaywallShownAndClosed / race-book-paywall | Hit area is too small: "Privacy" | `a11y-hit-region|test03RaceBookPaywallShownAndClosed|race-book-paywall|privacy` |
| P2 | a11y-hit-region |  | test03RaceBookPaywallShownAndClosed / race-book-paywall | Hit area is too small: "Restore Purchases" | `a11y-hit-region|test03RaceBookPaywallShownAndClosed|race-book-paywall|restore purchases` |
| P2 | a11y-hit-region |  | test03RaceBookPaywallShownAndClosed / race-book-paywall | Hit area is too small: "Terms" | `a11y-hit-region|test03RaceBookPaywallShownAndClosed|race-book-paywall|terms` |
| P2 | clipped |  | test02LockerRaceAndRankings / race-detail | button "Settings" is broken across 2 lines: * / Settings (AX3 text only) | `clipped|test02LockerRaceAndRankings|race-detail|gearshape.fill` |
| P2 | reduce-motion-ignored |  | all / all | with Reduce Motion on the journeys still moved for 34.6s against 37.1s without it (93%); check which animations ignore it | `reduce-motion-ignored|all|all|` |
| P3 | a11y-element-description |  | test01FirstRunClaimsAnAthlete / claim-results | Element has no description | `a11y-element-description|test01FirstRunClaimsAnAthlete|claim-results|` |
| P3 | a11y-element-description |  | test03RaceBookPaywallShownAndClosed / race-book-paywall | Label not human-readable: "$9.99" | `a11y-element-description|test03RaceBookPaywallShownAndClosed|race-book-paywall|$#` |

## Journeys

| Persona | Journey | Result | Seconds |
|---|---|---|---|
| newcomer | test01FirstRunClaimsAnAthlete | Passed | 27.331799030303955 |
| newcomer | test02LockerRaceAndRankings | Passed | 35.014742970466614 |
| newcomer | test03RaceBookPaywallShownAndClosed | Passed | 41.108994007110596 |
| newcomer | test04ReturnVisitWithInterruption | Passed | 62.913873076438904 |
| newcomer | testCoreLoopLockerRaceSurvivesRelaunch | Passed | 36.55122900009155 |
| accessibility | test01FirstRunClaimsAnAthlete | Passed | 27.651713013648987 |
| accessibility | test02LockerRaceAndRankings | Passed | 31.97159707546234 |
| accessibility | test03RaceBookPaywallShownAndClosed | Passed | 47.33492994308472 |
| accessibility | test04ReturnVisitWithInterruption | Passed | 59.86075401306152 |
| accessibility | testCoreLoopLockerRaceSurvivesRelaunch | Passed | 35.72749900817871 |
| reduce-motion | test01FirstRunClaimsAnAthlete | Passed | 27.690587997436523 |
| reduce-motion | test02LockerRaceAndRankings | Passed | 34.56819808483124 |
| reduce-motion | test03RaceBookPaywallShownAndClosed | Passed | 39.75922894477844 |
| reduce-motion | test04ReturnVisitWithInterruption | Passed | 69.77984988689423 |
| reduce-motion | testCoreLoopLockerRaceSurvivesRelaunch | Passed | 41.59399199485779 |
| duo | test01FirstRunClaimsAnAthlete | Passed | 35.31784796714783 |
| duo | test02LockerRaceAndRankings | Passed | 35.07973098754883 |
| duo | test03RaceBookPaywallShownAndClosed | Passed | 49.96312999725342 |
| duo | test04ReturnVisitWithInterruption | Passed | 65.34280204772949 |
| duo | testCoreLoopLockerRaceSurvivesRelaunch | Passed | 43.88376700878143 |

## Motion

| Persona | Motion s | Windows | Candidates | Gaps > 25 ms | 60 fps |
|---|---|---|---|---|---|
| newcomer | 37.139 | 54 | 22 | 144 | True |
| accessibility | 41.47 | 52 | 8 | 151 | True |
| reduce-motion | 34.593 | 55 | 17 | 113 | True |

## Launch entrances to look at

Each launch's frames after the springboard zoom, left to right then down, 4 frames per
row at the recorded rate. A blank stretch, text that reflows, or content that arrives and
pushes the layout is a finding: `qa-gate ledger <repo> add`.

- [entrance-01-test01firstrunclaimsanathlete.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/newcomer/entrance-01-test01firstrunclaimsanathlete.png)
- [entrance-05-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/newcomer/entrance-05-launchseeded.png)
- [entrance-09-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/newcomer/entrance-09-launchseeded.png)
- [entrance-01-test01firstrunclaimsanathlete.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/accessibility/entrance-01-test01firstrunclaimsanathlete.png)
- [entrance-05-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/accessibility/entrance-05-launchseeded.png)
- [entrance-09-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/accessibility/entrance-09-launchseeded.png)
- [entrance-13-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/accessibility/entrance-13-launchseeded.png)
- [entrance-19-test04returnvisitwithinterruption.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/accessibility/entrance-19-test04returnvisitwithinterruption.png)
- [entrance-21-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/accessibility/entrance-21-launchseeded.png)
- [entrance-23-testcorelooplockerracesurvivesrelaunch.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/accessibility/entrance-23-testcorelooplockerracesurvivesrelaunch.png)
- [entrance-01-test01firstrunclaimsanathlete.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/reduce-motion/entrance-01-test01firstrunclaimsanathlete.png)
- [entrance-05-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/reduce-motion/entrance-05-launchseeded.png)
- [entrance-09-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/reduce-motion/entrance-09-launchseeded.png)
- [entrance-13-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/reduce-motion/entrance-13-launchseeded.png)
- [entrance-19-test04returnvisitwithinterruption.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/reduce-motion/entrance-19-test04returnvisitwithinterruption.png)
- [entrance-21-launchseeded.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/reduce-motion/entrance-21-launchseeded.png)
- [entrance-23-testcorelooplockerracesurvivesrelaunch.png](/Users/jackwallner/ironman-ship/build/qa/4e259be6d1ff/reduce-motion/entrance-23-testcorelooplockerracesurvivesrelaunch.png)

Skipped personas: german (app not localized).
