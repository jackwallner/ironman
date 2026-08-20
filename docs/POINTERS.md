# Publishing the Tri Pointers episodes

The app reads `docs/pointers.json` from this repo's GitHub Pages site at launch
and caches it for twelve hours. Adding, re-ordering, or correcting an episode is
a commit and a push — no App Store release, no review queue.

## Schema

```json
{
  "title": "Tri Pointers",
  "subtitle": "21 episodes from Tri Patties Pointers.",
  "emptyMessage": "Shown only when \"pointers\" is empty.",
  "pointers": [
    {
      "id": "ep-01",
      "episode": 1,
      "title": "Sighting in a crowded swim start",
      "summary": "One line under the title.",
      "discipline": "swim",
      "videoURL": "https://…/ep-01.mp4",
      "linkURL": null,
      "thumbnailURL": null,
      "durationSeconds": 174,
      "isFree": true
    }
  ]
}
```

- `discipline` is one of `swim`, `t1`, `bike`, `t2`, `run`, `transitions`,
  `finish`, or omitted. It drives the filter chips, which only appear once two
  or more distinct values are present.
- `videoURL` must be something `AVPlayer` can stream — an `.mp4` or an HLS
  `.m3u8`. It plays inside the app.
- `linkURL` is the fallback for anything that is not a direct file (a YouTube
  watch page, for instance). The app hands it to the system browser instead of
  playing it. Set one or the other, not both.
- `isFree` episodes play for everyone. Everything else opens the paywall. Two or
  three free episodes is the usual shape: enough to show what the library is,
  not enough to replace it.

## Hosting the video files

GitHub Pages will serve an `.mp4` committed under `docs/`, but a 100 MB repo of
video is a bad trade and Pages has a soft 1 GB limit. Put the files anywhere
that serves `Content-Type: video/mp4` over HTTPS with range requests (S3 +
CloudFront, Cloudflare R2, Bunny) and point `videoURL` at that.

## Checklist

1. Encode each clip to H.264/AAC MP4, 1080p or less.
2. Upload and confirm the URL plays in Safari.
3. Add the entry to `docs/pointers.json`.
4. `python3 -m json.tool docs/pointers.json` to confirm it parses.
5. Commit and push. Pull to refresh in the app's Pointers tab to see it.
