---
paths:
  - "IronSplits/Views/**/*.swift"
  - "IronSplits/Info.plist"
  - "IronSplitsUITests/IPadLayoutUITests.swift"
  - "project.yml"
---

# iPad layout (1.2.0)

Native iPad since 1.2.0: `TARGETED_DEVICE_FAMILY "1,2"`, all four orientations
(`UISupportedInterfaceOrientations~ipad`). A shipped iPad build can never be
removed, so keep this bar.

- **Reading column.** Every scrolling screen ends in `.triReadableColumn()`
  (640pt, `TriGeo.readableWidth`, centred on the canvas). It is a no-op at
  phone width. Apply it to the `ScrollView` or `List` itself, never to a whole
  screen, which would narrow the navigation bar too.
- **Locker is list plus race.** On an iPad whose Locker is at least 700pt wide,
  `LockerView` shows the list (`TriGeo.masterWidth`, 440) beside a
  `RaceDetailPane`, the same pane the Duo uses; rows select instead of push.
  Narrower (Split View third or half, any iPhone) it pushes as before. It is one
  HStack whose detail pane appears as a sibling, never an `if` swap of two
  trees, so the list keeps its scroll.
- **Duo split is iPhone only.** `RootTabView.split` returns nil unless the idiom
  is `.phone`. The tabs stay full width on an iPad.
- Sheets (paywall, athlete search, note editor, review) take the system form
  sheet on iPad; do not force `.large` detents wider than that.
- No new labels or helper text for iPad. If a wide screen looks empty, fix the
  layout.
- **Verify** with `IPadLayoutUITests` through `gh-sim all --device 'iPad Pro
  13-inch (M5)' --scheme IronSplitsUITests --only IronSplitsUITests/IPadLayoutUITests`.
  It attaches every main screen, onboarding and the paywall in portrait and
  landscape. Look at every frame.
- The ASC capture test (`ASCReleaseCaptureUITests`) taps a race and expects a
  push; on iPad the Locker selects into the pane instead, so the iPad capture
  skips the back tap.
