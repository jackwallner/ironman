# Screenshot audit: iron-splits

Status: **PASS**
Disposition: **RELEASE-READY**
Target: `iphone_69` at `1320x2868`
Capture status: `ok`

This report combines file-spec checks with an independent thumbnail and OCR pass. Open each `contact-sheet.png` and `search-grid.png` before approving a set.

## Warnings

- race-book-evidence: 01-turn-history-into-a-story.png: thumbnail OCR missed header words ['turn', 'into']
- race-book-evidence: 02-see-where-you-found-time.png: thumbnail OCR missed header words ['see', 'where', 'found', 'time']
- race-book-evidence: 05-build-a-race-book-you-can-share.png: thumbnail OCR missed header words ['can', 'share']
- race-book-evidence: 06-find-your-fastest-split.png: thumbnail OCR missed header words ['find', 'your', 'fastest', 'split']

## Market brief

- Category: triathlon and endurance race-history apps
- Audience: athletes who want their published race history, splits, and progress in one private place
- Problem: Official results are scattered across event pages, and a finish time alone does not explain where an athlete found or lost time.
- Advantage: IM Iron Splits finds published results by name, keeps race kinds comparable, ranks every split, and turns the career record into a private Race Book with comparison and export tools.
- Competitive context: Event result pages show one race at a time, while training platforms usually require manual entry. IM Iron Splits uses published results as the source of truth, needs no account, and keeps the record on the phone.

## Sets

| Set | Status | Frames |
| --- | --- | ---: |
| `race-book-evidence` | pass | 8 |

## Review contract

- Contract: `single-header-benefit-story-v3`.
- Every creative frame has exactly one large, period-free header capped at two lines. Eyebrows and subheaders are forbidden.
- Phone frames use at least 50% of the canvas for literal UI evidence.
- The selected submission set contains six to eight frames. Other sets and background variants are review alternatives, not additional ASC inventory.
- Every visible header pitches a concrete benefit backed by a per-frame problem, advantage, search term, and literal UI proof.
- The first three frames must communicate separate market value at search scale.
- Every frame declares source, source_evidence, capture_flow, device, and evidence_status. Canonical frames map one-to-one to capture-report records.
- The app screen must be real capture evidence from the referenced build.
- Health and wellness copy must stay complementary and non-diagnostic.
- Re-run the audit after every copy, source, or layout change.
