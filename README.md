# IM Iron Splits

Your triathlon and running race results, found by name and ranked by split.

Type your name once. Every race you have finished loads with full swim/T1/bike/T2/run
splits, bib numbers, and age-group and overall places, going back to your first
start — then gets ranked the way athletes actually think about it: which race
held your fastest bike, and how far off it you are now.

iOS 17+, SwiftUI, Swift 6. See `CLAUDE.md` for the architecture and the feed's
sharp edges, `backend/README.md` for the command-line tools and why there is no
server, and `docs/POINTERS.md` for publishing the coaching-clip library.

## Build

```bash
xcodegen generate
agent-sim checkout ironsplits && UDID=$(agent-sim udid ironsplits) && agent-sim boot ironsplits
xcodebuild -project IronSplits.xcodeproj -scheme IronSplits -destination "id=$UDID" build
xcodebuild test -project IronSplits.xcodeproj -scheme IronSplits -destination "id=$UDID"
agent-sim checkin ironsplits
```

The UI tests hit the live results feed on purpose — the claim flow is a search
against someone else's service, and a mock would only prove the mock still
matches what was written down.

## Before it can ship

- [ ] App Store Connect app record for `com.jackwallner.ironman`, then set
      `AppStoreReviewLinks.appStoreID`
- [ ] RevenueCat project + the three products, then set `IronSplitsSecrets.revenueCatKey`
      (empty today, which is why Pro is inert rather than misbilled)
- [ ] Enable GitHub Pages on this repo so `docs/api-config.json` — the app's
      hotfix channel — is actually served
- [ ] Encode and host the Tri Pointers clips, then fill in `docs/pointers.json`
