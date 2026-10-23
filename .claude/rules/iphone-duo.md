---
paths:
  - "IronSplits/Views/RootTabView.swift"
  - "IronSplits/Views/LockerView.swift"
  - "Shared/Utilities/UnfoldedSplit.swift"
---

# iPhone Duo (2026-10-21)

- Unfolded (regular width, at least 720 pt), `RootTabView` puts the tabs and
  the tab bar on the leading side of the fold and `RaceDetailPane` on the
  trailing side: the Locker list beside the race it has open. The pane shows
  the latest finish until the athlete picks a row. Fold edges come from
  `GeometryProxy.verticalFold()` (iOS 27.1 `reservedRegions(.division)`), else
  an even split. Folded and every ordinary iPhone keep the single column.
- `RacePane` is in the environment only while split. That is how Locker rows
  know to select into the pane instead of pushing. Each pane gets
  `horizontalSizeClass = .compact` so it lays out as on a phone.
- Folding only changes frames: the tabs stay mounted in one tree, so their
  navigation and scroll survive. Never swap layouts with an `if`.
- The default pane opens quietly (`RaceDetailView.opensQuietly`): it does not
  count toward the review prompt or fire Pattie until the athlete picks it.
- Unfolded, every tab ends above the floating tab bar (`clearsTabBar`, a gap
  plus a short fade into the canvas), so no row sits under the bar's glass.
  Folded keeps the system bar over scrolling content as before.
- The inner display's status bar is a vertical column on the trailing edge
  and insets the detail pane's trailing safe area. The pane's race ignores
  that inset horizontally, otherwise every card sits off centre.
- Capture: `gh-sim all --device 'iPhone Duo' --args "-UITest -ResetLocker
  -SeedScreenshotData -AuditLight"` plus one `--screen "-DuoScreen <s>"` per
  surface: `locker`, `races`, `rankings`, `racebook`, `explore`, `tips`
  (DEBUG, `DuoScreen` in `RootTabView`). Never `--url`: on iOS 27.1 every
  custom-scheme openurl raises an "Open in" alert.
- Record in a separate `gh-sim launch --record-seconds`: in `all`
  (2026-10-21) the test recording never stopped and blocked the launch
  recordings ("A recording is already in progress").
