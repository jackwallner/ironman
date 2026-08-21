#!/usr/bin/env python3
"""Turn Tri Patties Pointers clips into `docs/pointers.json` entries.

Two sources, same output:

    scripts/ingest-pointers.py ~/Movies/tri-patties     # a folder of clips
    scripts/ingest-pointers.py <youtube playlist/video URL>

Each clip is transcoded to the H.264/AAC MP4 the in-app `AVPlayer` streams,
given a poster frame, measured, and merged into the catalog. Merging is by
`id`, and it only ever fills in fields that are empty: titles, summaries and
disciplines written by hand survive a re-run, so this can be run again when a
clip is re-cut without losing the copy around it.

Nothing is uploaded. `videoURL` is left pointing at `--base-url` (or null), and
`docs/POINTERS.md` covers hosting.
"""

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
CATALOG = REPO / "docs" / "pointers.json"
VIDEO_SUFFIXES = {".mp4", ".mov", ".m4v", ".avi", ".mkv", ".webm"}

# The leg a clip is about, guessed from its filename so a well-named folder
# needs no hand-editing.
DISCIPLINE_HINTS = [
    ("transitions", ("transition", "t1t2", "t1-t2")),
    ("t1", ("t1", "swim-to-bike", "swimtobike")),
    ("t2", ("t2", "bike-to-run", "biketorun")),
    ("swim", ("swim", "open water", "openwater", "sighting", "wetsuit", "goggle")),
    ("bike", ("bike", "cycling", "aero", "watts", "cadence", "flat tire")),
    ("run", ("run", "brick", "pace", "shoe")),
    ("finish", ("finish", "chute", "race day", "raceday", "taper", "nutrition")),
]


def die(message: str) -> "None":
    sys.exit(f"ingest-pointers: {message}")


def run(cmd: list, **kwargs):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kwargs)


def probe_seconds(path: pathlib.Path) -> "int | None":
    try:
        out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                   "-of", "default=noprint_wrappers=1:nokey=1", str(path)]).stdout
        return int(round(float(out.strip())))
    except (subprocess.CalledProcessError, ValueError):
        return None


def slug(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def title_from(stem: str) -> str:
    """"03 - sighting_in_a_crowded_swim_start" -> "Sighting in a crowded swim start"."""
    cleaned = re.sub(r"^[\s\d]*[-_.\s]+", "", stem)
    cleaned = re.sub(r"[_\-]+", " ", cleaned).strip()
    return cleaned[:1].upper() + cleaned[1:] if cleaned else stem


def episode_from(stem: str) -> "int | None":
    match = re.match(r"\s*(?:ep(?:isode)?[\s_-]*)?(\d{1,2})\b", stem, re.I)
    return int(match.group(1)) if match else None


def discipline_from(text: str) -> "str | None":
    """The leg named earliest in the filename wins.

    Titles routinely mention two legs, and the first one is the subject:
    "Brick run off the bike" is a run drill, not a bike one. Scanning in list
    order would file it under bike purely because bike sits higher in the list.
    """
    haystack = text.lower()
    best, best_at = None, len(haystack) + 1
    for discipline, needles in DISCIPLINE_HINTS:
        for needle in needles:
            at = haystack.find(needle)
            if at != -1 and at < best_at:
                best, best_at = discipline, at
    return best


def fetch_youtube(url: str, into: pathlib.Path) -> "list[pathlib.Path]":
    if not shutil.which("yt-dlp"):
        die("yt-dlp is not installed (brew install yt-dlp)")
    into.mkdir(parents=True, exist_ok=True)
    print(f"==> Downloading {url}")
    try:
        run(["yt-dlp", "-f", "bv*[height<=1080]+ba/b[height<=1080]/b",
             "-o", str(into / "%(playlist_index|)s%(title)s.%(ext)s"),
             "--restrict-filenames", "--no-playlist-reverse", url])
    except subprocess.CalledProcessError as error:
        die(f"yt-dlp failed:\n{error.stderr.strip()}")
    return sorted(p for p in into.iterdir() if p.suffix.lower() in VIDEO_SUFFIXES)


def transcode(source: pathlib.Path, out_dir: pathlib.Path, name: str) -> "tuple[pathlib.Path, pathlib.Path]":
    """H.264/AAC, <=1080p, faststart so it streams before it finishes loading."""
    out_dir.mkdir(parents=True, exist_ok=True)
    video = out_dir / f"{name}.mp4"
    poster = out_dir / f"{name}.jpg"
    print(f"    encoding {source.name} -> {video.name}")
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(source),
         "-vf", "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease",
         "-c:v", "libx264", "-preset", "slow", "-crf", "21", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(video)])
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(video),
         "-ss", "00:00:01", "-frames:v", "1", "-q:v", "3", str(poster)])
    return video, poster


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", help="folder of clips, or a YouTube video/playlist URL")
    parser.add_argument("--out", default=str(REPO / "build" / "pointers"),
                        help="where encoded mp4s and posters are written")
    parser.add_argument("--base-url", default=None,
                        help="public prefix the files will be served from, e.g. "
                             "https://cdn.example.com/pointers")
    parser.add_argument("--free", type=int, default=2,
                        help="how many leading episodes play without Pro (default 2)")
    parser.add_argument("--dry-run", action="store_true", help="probe and report, encode nothing")
    args = parser.parse_args()

    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            die(f"{tool} is not installed (brew install ffmpeg)")

    out_dir = pathlib.Path(args.out).expanduser()
    if args.source.startswith(("http://", "https://")):
        clips = fetch_youtube(args.source, out_dir / "download")
    else:
        folder = pathlib.Path(args.source).expanduser()
        if not folder.is_dir():
            die(f"{folder} is not a folder")
        clips = sorted(p for p in folder.iterdir() if p.suffix.lower() in VIDEO_SUFFIXES)
    if not clips:
        die("no video files found")
    print(f"==> {len(clips)} clip(s)")

    catalog = json.loads(CATALOG.read_text()) if CATALOG.exists() else {
        "title": "Tri Pointers", "subtitle": None, "emptyMessage": None, "pointers": []
    }
    existing = {p["id"]: p for p in catalog.get("pointers", [])}

    entries = []
    for index, clip in enumerate(clips, start=1):
        episode = episode_from(clip.stem) or index
        pointer_id = f"ep-{episode:02d}"
        name = f"{pointer_id}-{slug(title_from(clip.stem))}"[:60].rstrip("-")

        seconds = probe_seconds(clip)
        if args.dry_run:
            print(f"    {pointer_id}  {clip.name}  {seconds or '?'}s")
            video_name = f"{name}.mp4"
            poster_name = f"{name}.jpg"
        else:
            video, poster = transcode(clip, out_dir / "encoded", name)
            seconds = probe_seconds(video) or seconds
            video_name, poster_name = video.name, poster.name

        entry = dict(existing.get(pointer_id, {}))
        entry["id"] = pointer_id
        entry.setdefault("episode", episode)
        entry.setdefault("title", title_from(clip.stem))
        entry.setdefault("summary", None)
        if not entry.get("discipline"):
            entry["discipline"] = discipline_from(clip.stem)
        entry["durationSeconds"] = seconds
        if args.base_url:
            base = args.base_url.rstrip("/")
            entry["videoURL"] = f"{base}/{video_name}"
            entry["thumbnailURL"] = f"{base}/{poster_name}"
        else:
            entry.setdefault("videoURL", None)
            entry.setdefault("thumbnailURL", None)
        entry.setdefault("linkURL", None)
        entry["isFree"] = entry.get("isFree", episode <= args.free)
        entries.append(entry)

    entries.sort(key=lambda e: (e.get("episode") or 0, e["id"]))
    catalog["pointers"] = entries
    catalog.setdefault("title", "Tri Pointers")
    if not catalog.get("subtitle"):
        catalog["subtitle"] = f"{len(entries)} episodes from Tri Patties Pointers."

    if args.dry_run:
        print("==> dry run, catalog not written")
    else:
        CATALOG.write_text(json.dumps(catalog, indent=2) + "\n")
        print(f"==> wrote {len(entries)} episode(s) to {CATALOG.relative_to(REPO)}")
    if not args.base_url:
        print("    videoURL left null: re-run with --base-url once the files are hosted "
              "(see docs/POINTERS.md).")


if __name__ == "__main__":
    main()
