---
paths:
  - "IronSplits/**"
  - "Shared/**"
  - "IronSplitsTests/LocalizationTests.swift"
  - "Tools/Localization/**"
---

# IM Tri Tracker: localization (added 2026-10-30)

The app ships in English plus de, es, fr, it, ja, nl, pl and pt-BR. It was not
in the 2026-10-28 fleet wave, so the list is the fleet's top non-English
markets. Pattern copied from Sober (`.claude/rules/localization.md` there).

## Setup
- One catalog, `Shared/Localizable.xcstrings` (source `en`, every key
  `extractionState: manual`), compiled by the app target and visible to tests
  through the host app. XcodeGen 2.39+ reads its languages into
  `knownRegions`; `IronSplits/Info.plist` also lists them in
  `CFBundleLocalizations`. No `InfoPlist.xcstrings`: there are no permission
  purpose strings and the display name is the brand.
- `python3 Tools/Localization/check.py` (repo root, no Xcode needed) fails on
  a source literal with no key, a key missing a language, mismatched format
  specifiers, or a bare literal passed to one of the app's own components
  (`TriPlaceholder`, `TriChip`, `StatTile`, ... take a `String`, so the call
  site passes `String(localized:)`). `#if DEBUG` code is skipped. Run it
  before every build that touches copy.
- The checker matches interpolations loosely, so it cannot tell `%@` from
  `%lld`. When adding a key with an interpolated `Int`, write the catalog key
  with `%lld` by hand or the lookup silently falls back to English.
- `LocalizationTests` proves every `.lproj` ships, Polish plurals pick
  one/few/many, and English plurals read "1 finish".

## Adding or changing copy
- `Text("literal")`, `Button`, `Label`, `Section`, `navigationTitle`, `alert`
  and friends localize themselves. Copy held in a `String` (enum titles,
  component parameters, PDF and image text, error messages) must be
  `String(localized: "...")`. Logs, OData filters, RevenueCat identifiers and
  stored keys stay plain.
- Whole sentences only, never spliced fragments: `Discipline.rankingsTitle`
  has one key per leg rather than "\(title) rankings". Counts are plural
  variations; Polish needs one/few/many/other. The two Race Book preview
  accessibility labels use a `%#@n@` substitution in some languages.
- No `.uppercased()`/`.capitalized` on translated text; use
  `localizedUppercase`. Dates use `RaceDate` (`formatted()`), ordinals use
  `Ordinal.text` (`NumberFormatter.ordinal`, so "3." in German and "第3" in
  Japanese; the keys around it are written for that).
- Prices only from StoreKit. Trial lengths are whole keys per unit.
- Untranslated on purpose: IM Tri Tracker, Race Book, Ask Pattie, Tri
  Pointers, T1/T2, DNF/DNS/DQ, IRONMAN®/70.3® in the disclaimer.
- Pattie's own words stay English: the Ask Pattie tree and episode catalog are
  hosted JSON built from her recordings (`docs/ask-pattie.json`,
  `docs/pointers.json`), and the speech-bubble lines in `PattieMode.deck` and
  `PattieVoice` captions match English voice clips. The Settings copy says her
  recordings are in English.
- `RaceBookBuilder.plainText` and `ResumeBuilder.plainText` stay English: no
  screen reaches them, and `RaceBookTests` pins their wording.
- Sport terms per market: Langdistanz/Mitteldistanz (de), larga/media
  distancia (es), longue/demi-distance (fr), distanza lunga/media (it),
  hele/halve afstand (nl), pełny dystans/połówka (pl), longa/meia distância
  (pt-BR), フル/ハーフ (ja). Locker is Spind, Taquilla, Casier, Armadietto,
  Locker, Szafka, Armário, ロッカー. Address: du, tú, vous, tu, je, ty
  (capitalized Twój/Ci), você, polite Japanese.

## Proving a change
`gh-sim all` with one `--screen` per language and surface, e.g.
`--screen "-AppleLanguages (de) -AppleLocale de_DE -UITest -ResetLocker"`
(onboarding search), `... -SeedScreenshotData -DuoScreen locker` (main
screen), `-DuoScreen rankings`, and `-DuoScreen racebook -PaywallSnapshot
lifetime` (DEBUG: the Race Book tab opens the paywall sheet itself).
