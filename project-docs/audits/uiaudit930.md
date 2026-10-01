# UI audit, 2026-09-30 (1.1.2)

Trigger: Pattie, on 1.1.1 (31) from the App Store, could not see the Locker
"Change" button (navy text on dark Liquid Glass) and the fourth career stat was
clipped ("29 PODIU..."). Both shipped past `LockerFlowUITests`, which asserted
the button existed, and past the design audit, whose simulator rendered the glass
light.

Method: every screen in light and dark on the iOS 26.5 lane (iPhone 17 Pro) and
the iOS 27 lane (iPhone 18 Pro), live feed plus seeded data, with the new
measured checks (bar control contrast at 4.5:1, no text off screen). The new
`ChromeLegibilityUITests` was first run against the 1.1.1 code and failed
(race detail back button at 1.67:1), so it detects this class of bug.

## Fixed

| Area | Problem | Fix |
| --- | --- | --- |
| Every nav bar | System glass flips light/dark by device; colours guessed it | `TriBarItem` hides the glass, `TriBarLabel` draws a fixed fill |
| Locker | Change button unreadable on device | White on `chromeFill`, with a people icon |
| Pushed screens | White chevron on pale glass, 1.7:1 | `TriBackButton` via `.triNavBar(pushed: true)`, edge swipe kept |
| Tips | White segment label on pale glass | `TriBarSegments` replaces the system segmented picker |
| Sheets | Cancel/Done/Save on glass; Cancel clipped by a 44pt slot | `TriBarLabel` with `.fixedSize()` |
| Locker, Explore | Fourth stat tile cut off by a horizontal scroller | `CareerStatsRow`, equal columns, 2x2 fallback |
| Locker | Header card square on top; filter rows far apart | Own section, rounded card, one filter section, 16pt section spacing |
| Race rows | Five PB badges wrapped "PB FINISH" inside each pill | Badges while they fit, else "5 PBs" |
| Rankings | "13:49:39" and "Personal best" wrapped | Fixed-size time column |
| Dark mode | Selected chips navy on near-black read as unselected | `selectedFill` / `inkOnSelected` tokens |
| Dark mode | "Full clip" and spinners in navy, invisible | `ink` / `inkSecondary` |
| Episodes | Summary squeezed into five lines by a metadata column | Metadata on the eyebrow line, summary two lines |

## Test changes

- `UIAuditAssertions.swift`: `assertLegible`, `assertNavigationBarLegible`
  (also fails unlabeled bar buttons), `assertNoTextRunsOffScreen`.
- `ChromeLegibilityUITests`: bar controls, sheets and paywall in both schemes.
- `DesignAuditUITests`: now walks Explore, the Change sheet, the Locker menu,
  rankings and the race-detail field, and measures every screenshot.
- Three stale tests repaired (they failed on 1.1.1 too): overall is the default
  field scope; two accessibility-size scrolls now clear the floating tab bar.

## Not covered by a measured check

Wrapping of numbers inside combined accessibility elements (the rankings time)
is invisible to XCUI. It was caught by looking at the screenshots, which is why
DESIGN.md section 9 still requires reviewing every exported image.
