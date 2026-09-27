# IM Iron Splits

Published full and half-distance triathlon results, found by registered name
and ranked by split within each distance.

The Locker keeps every supported result, split, bib and place free. Explore
opens another athlete's published history without changing your own. Race Book
adds like-for-like comparison and unlimited export with one lifetime purchase.

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

The UI tests hit the live results feed on purpose. The claim flow is a search
against someone else's service, and a mock would only prove the mock still
matches what was written down.

## Before it can ship

- [x] App Store Connect app record for `com.jackwallner.ironman` (`6803727074`),
      titled **IM Iron Splits: Race Results**, with `AppStoreReviewLinks.appStoreID`
      configured
- [x] RevenueCat project and the three products are configured; the production
      public key is set in `IronSplitsSecrets.revenueCatKey`
- [ ] Enable GitHub Pages on this repo so `docs/api-config.json`, the app's
      hotfix channel, is actually served
- [ ] Encode and host the Tri Pointers clips, then fill in `docs/pointers.json`
