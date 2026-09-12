---
paths:
  - "docs/pointers.json"
  - "docs/POINTERS.md"
  - "docs/ask-pattie.json"
  - "docs/pattie-voice.json"
  - "IronSplits/Resources/ask-pattie.json"
  - "IronSplits/Resources/PattieVoice/*"
  - "scripts/build-ask-pattie.py"
  - "scripts/cut-pattie-voice.py"
  - "scripts/ingest-pointers.py"
  - "scripts/pattie-transcripts.json"
  - "Shared/Services/PointerMedia.swift"
  - "Shared/Services/PattieVoice.swift"
  - "Shared/Services/PattieMode.swift"
  - "Shared/Models/Pointer.swift"
  - "Shared/Models/AskPattie.swift"
  - "IronSplits/Views/AskPattieView.swift"
  - "IronSplits/Views/PointersView.swift"
  - "IronSplits/Views/PattiePopup.swift"
  - "IronSplitsTests/AskPattieGuideTests.swift"
  - "IronSplits/Views/SettingsView.swift"
---

# IM Iron Splits: Pointers, Ask Pattie and Pattie's voice

Moved verbatim from CLAUDE.md. Loads when a matching file is read; update it here.

- **Pointers content is not in the app.** The catalog is fetched from
  `docs/pointers.json`; `docs/POINTERS.md` documents the schema and hosting.
- **The episodes cannot be streamed from where they are hosted, and this is not
  a bug in the player.** A GitHub release asset is served as
  `application/octet-stream` with `Content-Disposition: attachment`, after a
  redirect to a signed URL with no file extension in its path. `AVURLAsset`
  needs either the MIME type or the extension and that response gives it
  neither, so `VideoPlayer` showed a black rectangle. `PointerMediaCache`
  downloads to a local `.mp4` first, which also makes replays instant and works
  offline. If the media ever moves to a host that sends `video/mp4`, streaming
  would work again and the cache could go.
- **The hosted episode files are 426x240.** They will look soft full-screen on a
  phone. Re-encoding from higher-resolution originals (which are not in this
  repo) is worth doing before any App Store screenshot features the player.
- **Ask Pattie is a deterministic tree, not a chat.** `docs/ask-pattie.json`
  holds goals, topics and answers; the app bundles a copy as the offline
  fallback and hot-loads the hosted one. It costs nothing per question, can only
  surface advice Pattie actually gave on camera, and works with no signal.
  `scripts/build-ask-pattie.py` regenerates it and **refuses to publish a tree
  with a dead end**, so run it rather than hand-editing the JSON.
- **Pattie's voice clips are cut from her own episodes** by
  `scripts/cut-pattie-voice.py`, using Whisper word timestamps snapped to the
  nearest real silence. There are 56 in `IronSplits/Resources/PattieVoice/`:
  18 sign-offs, 19 situation hooks, 19 solutions. Nothing is synthesised, and
  nothing should be.
