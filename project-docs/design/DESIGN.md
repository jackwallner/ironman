# IM Tri Tracker: design system

One file, and the rule for every UI change in this repo: **follow it, or change
it here first.** Anything hardcoded in a view that this file names as a token is
a bug, whoever wrote it.

The point is not taste for its own sake. Users decide whether an app looks
credible in well under a second, and everything after that gets filtered through
the decision. Inconsistent spacing, three border radii on one screen and a light
palette wearing a dark navigation bar are the specific things people read as
"nobody looked at this before it shipped".

Everything below lives in `IronSplits/Views/TriDesign.swift`.

---

## 1. Type: SF Pro, three weights

The system face, because it is the face the rest of the phone is set in and
nothing else on a screen full of numbers reads as trustworthy next to it. No
bundled fonts.

Weights: `.regular` for prose, `.semibold` for emphasis, `.bold` for hero
numbers only. That's it. No `.heavy`, no `.medium`.

| Token | Size | Use |
| --- | --- | --- |
| `TriType.athleteName` | 28 bold | The claimed athlete, once, in the locker header |
| `TriType.pageTitle` | 22 bold | Race name in a detail hero |
| `TriType.cardTitle` | 17 semibold | Card and row titles |
| `TriType.field` | 17 regular | **Text fields only** |
| `TriType.body` / `bodyBold` | 16 | Body copy |
| `TriType.small` / `smallBold` | 13 | Secondary copy, chips |
| `TriType.sectionTitle` | 13 semibold | Uppercase section headers |
| `TriType.micro` | 11 semibold | Badges, footnotes, eyebrows |
| `TriType.stat*` | 13 / 16 / 22 / 40 | **All numbers** |

**Every numeric style is `.monospacedDigit()`.** A finish time that reshuffles
its own columns as the digits change is the cheapest tell there is, and this app
is nothing but numeric columns.

**Text fields are 17pt in a 44pt+ box.** They were 15pt in a 12pt box, which is
smaller than every native field on the phone and reads as a web form in a
wrapper.

## 2. Space: one 4pt scale

`TriSpace.x1` = 4 … `x10` = 40. No arbitrary padding values anywhere. If a
layout wants 14, it takes 12 or 16.

Page margin, card padding and section gaps come off `TriGeo.padPage`,
`padCard`, `padSection`, which are themselves scale values.

## 3. Colour: semantic tokens, no hex in a view

Eight structural roles, one brand pair, two status colours:

`canvas` · `surface` · `surfaceAlt` · `surfaceSunk` · `hairline` · `divider` ·
`ink` · `inkSecondary` · `inkTertiary`, then `deep` and `sunrise`, then
`positive` and `negative`.

Plus two ramps, `color(for: Discipline)` and the percentile pair.

**Every one of them is built through `adaptive(light:dark:)`**, which resolves
inside `UIColor(dynamicProvider:)`. That is deliberate and it is the fix for the
biggest visual bug the app had: SwiftUI's `@Environment(\.colorScheme)` does not
reach UIKit-backed surfaces (nav bars, `Form` rows, share sheets), so a palette
of literal light colours produced a light app wearing dark system chrome.
Resolving at the `UIColor` layer means the token decides late enough to be right
everywhere.

Rules:

- A view never names a literal colour. It names a token.
- `deep` lifts slightly in dark mode so a navy hero does not dissolve into a
  near-black canvas.
- `inkOnDark` is the only fixed colour, because `deep` is dark in both schemes.
- One accent. `sunrise` means "your best" or "the one action on this screen".
  Nothing else gets to be an accent, which is why the old single-call-site
  `linkBlue` is gone.
- The percentile *text* ramp is separate from the *fill* ramp on purpose: the
  fill passes through a mid neutral at the 50th percentile, which is right for a
  bar and unreadable as type.
- Status bar content stays light because every app navigation bar uses `deep`,
  including in the light appearance.
- **Never use `deep` as text or a spinner tint on a surface.** It is navy in
  both schemes, so it vanishes on a dark card. Text is `ink`; spinners are
  `inkSecondary`. `deep` is a fill.
- Selection is `selectedFill` with `inkOnSelected`: navy with white in light
  mode, a light fill with dark ink in dark mode. Navy selection on a dark
  canvas read as unselected.

## 4. Radius: one for surfaces, one for what sits inside them

`TriGeo.radiusCard` = 12 for every card, sheet, field and button.
`TriGeo.radiusInner` = `radiusBadge` = 8 for thumbnails and badges inside a card.
Everything else is a `Capsule`.

**Always `style: .continuous`.** Apple's corners are continuous curves, not
plain rounded rectangles, and squircles versus circular arcs is one of the
subtlest premium tells on the platform. There is no reason to ever pass
`.circular`.

## 5. Elevation: two shadows

`TriShadow.card` for a card on the canvas, `TriShadow.floating` for something
over the whole screen. Both take the colour scheme, because a light-mode shadow
is invisible on a dark canvas. There is no third. Shadows say how high a thing
is; they are not decoration.

## 6. Interaction: nothing is dead

- Every button uses `.triPress` (with haptic) or `.triPressSilent` (without,
  when the action fires its own). It dips to 0.97 and dims on press.
- **Haptics on anything that means something.** `Haptics.selection()` for a
  filter or tab change, `Haptics.tap()` for committing, `Haptics.success()` for
  an outcome. A polished-looking interface that does not answer the thumb reads
  as broken.
- **44pt minimum tap target**, via `.triTapTarget()` or an explicit
  `frame(minHeight: TriGeo.tapTarget)`. Below it the app feels fiddly in a way
  users report as "buggy". The filter chips were 30pt.
- One chip component, `TriChip`. There were three near-identical copies at three
  different heights, none of which cleared 44.
- One primary button, `TriPrimaryButton`.

## 7. Navigation bar chrome

Every control on the navy bar is a `TriBarLabel` (white on the fixed
`chromeFill` capsule, a circle when icon-only) inside a `TriBarItem`, which
switches the iOS 26 system glass off. Pushed screens use
`.triNavBar(pushed: true)` for the matching `TriBackButton`; the edge swipe
still works. Mode switches on the bar are `TriBarSegments`, not a system
segmented `Picker`.

Why: Liquid Glass picks light or dark from what it samples under it, not from
the bar's colour scheme. 1.1.1 guessed "light glass, navy text" for Change;
the simulator agreed and Pattie's iPhone rendered dark glass, so the button was
navy on navy. The same lottery put white chevrons and white segment labels on
pale glass. Nothing on the bar may depend on what the glass decides.

## 8. Native feel

- Real `NavigationStack` with a real navigation path, so the system back button
  and the back-swipe work. Ask Pattie drives one.
- Five tabs, maximum. This is why Ask Pattie rides inside the Pattie tab behind a
  nav-bar segmented control rather than becoming a sixth.
- Sheets for secondary screens.
- Safe areas respected. `ignoresSafeArea` is for backgrounds, never content.
- `.inline` navigation titles where a screen already draws its own header, so a
  large title does not leave an empty navy band above a card that repeats it.

## 9. The audit, and what it must measure

Before any release with UI changes, run both measured suites on **two** lanes,
the iOS 26 phone (`agent-sim checkout ironsplits --slot 1`) and the default
iOS 27 phone, and in both schemes:

```
xcodebuild test -scheme IronSplitsUITests ... -only-testing:IronSplitsUITests/ChromeLegibilityUITests
xcrun simctl ui <udid> appearance light   # then dark
TEST_RUNNER_IRON_SPLITS_AUDIT_APPEARANCE=light xcodebuild test -scheme IronSplitsUITests ... \
  -only-testing:IronSplitsUITests/DesignAuditUITests/testEveryScreen
```

`ChromeLegibilityUITests` fails any bar control under 4.5:1 contrast and any
text that runs off the screen edge. `DesignAuditUITests` runs the same two
checks on every screenshot it takes. Then export the attachments
(`xcrun xcresulttool export attachments`) and look at every screen. A test that
only asserts an element *exists* proves nothing about whether anyone can see
it; that gap is how 1.1.1 shipped. A new screen or bar control is not done until
the audit walk reaches it.

The questions to ask of every screenshot:

1. Any font that is not SF, or a fourth weight?
2. Any padding that is not on the 4pt scale?
3. Any literal colour in a view?
4. More than the two radii, or a `.circular` corner?
5. More than the two shadows?
6. Anything tappable with no pressed state, no haptic, or under 44pt?
7. Anything that looks right in light and wrong in dark?

---

## Where design effort goes

In funnel order, not evenly:

1. **Icon and App Store screenshots.** They convert before anyone opens the app.
2. **Onboarding.** Here that is exactly one screen: type your name, see your
   races. It is also the screen that was taking thirty seconds to answer, which
   is a design problem before it is a performance one.
3. **The first ten seconds inside.** The locker with real splits on it.
4. **Everything else.** Settings does not need to be beautiful.
