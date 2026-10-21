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
- Capture: `gh-sim all --device 'iPhone Duo' --args "-UITest -ResetLocker
  -SeedScreenshotData -AuditLight -CaptureTour" --wait 12` plus `--url
  noop://1` through `noop://5`. The failing noop URLs only pace extra shots;
  the DEBUG tour walks six screens on a timer because gh-sim shoots on its own
  clock and `simctl openurl` with a real scheme raises a confirmation alert.
- Record in a separate `gh-sim launch --record-seconds`: in `all`, the test
  recording never stops and blocks the launch recordings ("A recording is
  already in progress").
