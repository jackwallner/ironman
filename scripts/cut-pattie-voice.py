#!/usr/bin/env python3
"""Cut Pattie's voice clips out of her own episodes.

Nothing in this app is synthesised. Every line she speaks is a slice of a real
Tri Pattie's Pointers video, which means the interesting problem is finding cut
points that do not clip a word or leave half of the previous one hanging on the
front.

Three families come out of it, because every episode is cut to the same shape:

  pattie-hook-NN      "Here's the situation. <the situation>"   ~7-12s
  pattie-solution-NN  "Here's the solution. <the fix>"          ~8-16s
  pattie-signoff-NN   "Now that's a great idea."                ~1.2-2.4s

The sign-offs are the ones that matter most for Pattie Mode: eighteen separate
takes of the same line from eighteen different episodes, so a popup can react to
something without ever using the same recording twice in a session.

How the edges are found:

  1. Whisper word timestamps locate the phrase.
  2. The end is snapped to the last sentence-ending word inside the window, so a
     clip ends on a full stop rather than a stopwatch.
  3. Both edges are then nudged into a bounded silence just outside the phrase.
     Word times are close but not frame-accurate, and an in-point two frames
     early drags the tail of the previous word into the clip.
  4. Anything that still starts hot (she runs straight on with no pause to cut
     into) gets a longer fade-in instead, which is the editorial answer when
     there is no silence to find.

Requires ffmpeg. Transcripts live in `scripts/pattie-transcripts.json`; regenerate
them with openai-whisper (`small.en`, `word_timestamps=True`) if the episodes
change.

Usage:  python3 scripts/cut-pattie-voice.py <dir-of-episode-mp4s>
Writes: IronSplits/Resources/PattieVoice/
"""
import json
import math
import os
import re
import subprocess
import sys
import wave
import array

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRANSCRIPTS = os.path.join(ROOT, "scripts", "pattie-transcripts.json")
OUT = os.path.join(ROOT, "IronSplits", "Resources", "PattieVoice")

SENT_END = re.compile(r"[.!?]$")
SIGNOFFS = ["now that's a great idea", "that's a great idea", "that is a great idea",
            "now that's a good idea", "that's a bonus idea", "that's always a great idea"]
SOLUTION_CUES = ["here's the solution", "so here's the solution", "well here's the solution",
                 "here's what you want to do", "here's what i do", "what's the solution",
                 "here's the neat thing", "so what's the solution",
                 "so i've got a word for you to remember"]
# The edge level, relative to the clip's own peak, above which a cut point is
# treated as landing mid-speech.
HOT_EDGE_DB = -18.0
AUDIO_SAMPLE_RATE = 48000
AUDIO_BITRATE = "96k"
DEFAULT_FADE_IN = 0.12
FADE_OUT = 0.20


def words(transcript):
    out = []
    for segment in transcript["segments"]:
        for word in segment["words"]:
            raw = word.get("word", word.get("w", "")).strip()
            token = re.sub(r"[^a-z']", "", raw.lower())
            if token:
                out.append({"t": token, "raw": raw, "s": word["s"], "e": word["e"]})
    return out


def find(ws, phrase, last=False):
    target = phrase.split()
    hits = [i for i in range(len(ws) - len(target) + 1)
            if all(ws[i + j]["t"] == target[j] for j in range(len(target)))]
    if not hits:
        return None
    return hits[-1] if last else hits[0]


def snap_end(ws, start, minimum, maximum):
    """Last sentence-ending word in the window, else the biggest pause in it."""
    sentence, pause, widest = None, None, 0.0
    for i in range(start, len(ws)):
        span = ws[i]["e"] - ws[start]["s"]
        if span > maximum:
            break
        gap = (ws[i + 1]["s"] - ws[i]["e"]) if i + 1 < len(ws) else 1.0
        if span >= minimum:
            if SENT_END.search(ws[i]["raw"]):
                sentence = i
            if gap > widest:
                widest, pause = gap, i
    return sentence if sentence is not None else pause


class Episode:
    """One source clip, with a 10ms RMS envelope for finding real silence."""

    def __init__(self, mp4):
        self.mp4 = mp4
        self.wav = os.path.splitext(mp4)[0] + ".pattievoice.wav"
        if not os.path.exists(self.wav):
            run(["-i", mp4, "-ac", "1", "-ar", "16000", self.wav])
        handle = wave.open(self.wav)
        samples = array.array("h")
        samples.frombytes(handle.readframes(handle.getnframes()))
        handle.close()
        hop = 160
        self.envelope = [
            math.sqrt(sum(x * x for x in samples[i:i + hop]) / max(1, len(samples[i:i + hop])))
            for i in range(0, len(samples), hop)
        ]
        self.duration = len(samples) / 16000.0

    def quietest_between(self, start, end):
        """The quietest 10ms frame inside a bounded interval."""
        lo = max(0, int(start * 100))
        hi = min(len(self.envelope) - 1, int(end * 100))
        if hi <= lo:
            return max(0.0, min(self.duration, start))
        return min(range(lo, hi + 1), key=lambda i: self.envelope[i]) / 100.0


def run(args):
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y"] + args, check=True)


def encode(episode, name, start, end, fade_in=DEFAULT_FADE_IN):
    begin = episode.quietest_between(max(0.0, start - 0.45),
                                     max(0.0, start - 0.12))
    finish = episode.quietest_between(min(episode.duration, end + 0.08),
                                      min(episode.duration, end + 0.45))
    if finish - begin < 0.5:
        return None
    path = os.path.join(OUT, name + ".m4a")
    fade_out = max(0.0, finish - begin - FADE_OUT)
    run(["-ss", f"{begin:.3f}", "-t", f"{finish - begin:.3f}", "-i", episode.mp4,
         "-vn", "-ac", "1", "-ar", str(AUDIO_SAMPLE_RATE), "-c:a", "aac",
         "-b:a", AUDIO_BITRATE,
         "-af", f"afade=t=in:st=0:d={fade_in},afade=t=out:st={fade_out:.3f}:d={FADE_OUT},"
                "loudnorm=I=-16:TP=-2.0:LRA=11",
         path])
    return path, begin, finish


def normalize_existing(name, metadata):
    """Re-encode a first-pass phrase without changing its spoken content."""
    path = os.path.join(OUT, name + ".m4a")
    if not os.path.exists(path):
        return False
    duration = float(metadata.get("seconds", 0.0))
    fade_out = max(0.0, duration - FADE_OUT)
    temp = path + ".tmp.m4a"
    run(["-i", path, "-vn", "-ac", "1", "-ar", str(AUDIO_SAMPLE_RATE),
         "-c:a", "aac", "-b:a", AUDIO_BITRATE,
         "-af", f"afade=t=in:st=0:d={DEFAULT_FADE_IN},"
                f"afade=t=out:st={fade_out:.3f}:d={FADE_OUT},"
                "loudnorm=I=-16:TP=-2.0:LRA=11",
         temp])
    os.replace(temp, path)
    return True


def edge_levels(path):
    """(head dB, tail dB) relative to the clip's own peak."""
    scratch = path + ".check.wav"
    run(["-i", path, "-ac", "1", "-ar", "16000", scratch])
    handle = wave.open(scratch)
    samples = array.array("h")
    samples.frombytes(handle.readframes(handle.getnframes()))
    handle.close()
    os.remove(scratch)
    if not samples:
        return 0.0, 0.0
    peak = max(abs(x) for x in samples) or 1
    rms = lambda s: math.sqrt(sum(x * x for x in s) / max(1, len(s)))
    window = 1600
    return (20 * math.log10(max(rms(samples[:window]), 1) / peak),
            20 * math.log10(max(rms(samples[-window:]), 1) / peak))


def main(source_dir):
    os.makedirs(OUT, exist_ok=True)
    transcripts = json.load(open(TRANSCRIPTS))
    manifest, hot = {}, []
    record = os.path.join(ROOT, "docs", "pattie-voice.json")
    previous = json.load(open(record)) if os.path.exists(record) else {}
    preserved = {
        name: metadata for name, metadata in previous.get("clips", {}).items()
        if not (name.startswith("pattie-hook-") or
                name.startswith("pattie-solution-") or
                name.startswith("pattie-signoff-"))
    }

    for key in sorted(transcripts):
        mp4 = os.path.join(source_dir, key + ".mp4")
        if not os.path.exists(mp4):
            print(f"skip {key}: no {mp4}")
            continue
        episode = Episode(mp4)
        ws = words(transcripts[key])
        number = key.split("-")[1]

        plans = []
        for phrase in SIGNOFFS:
            i = find(ws, phrase, last=True)
            if i is not None:
                plans.append((f"pattie-signoff-{number}", i, i + len(phrase.split()) - 1, None))
                break

        i = find(ws, "here's the situation")
        if i is None:
            i = find(ws, "there's a situation")
        if i is not None:
            j = snap_end(ws, i, 4.0, 12.0)
            if j:
                plans.append((f"pattie-hook-{number}", i, j, None))

        for cue in SOLUTION_CUES:
            i = find(ws, cue)
            if i is not None:
                j = snap_end(ws, i, 6.0, 20.0)
                if j:
                    plans.append((f"pattie-solution-{number}", i, j, None))
                break

        for name, i, j, _ in plans:
            result = encode(episode, name, ws[i]["s"], ws[j]["e"])
            if not result:
                continue
            path, begin, finish = result
            head, tail = edge_levels(path)
            if head > HOT_EDGE_DB:
                # No silence to cut into; ramp the front instead.
                encode(episode, name, ws[i]["s"], ws[j]["e"], fade_in=0.30)
                head, tail = edge_levels(path)
                hot.append(name)
            manifest[name] = {
                "seconds": round(finish - begin, 2),
                "episode": key,
                "text": " ".join(w["raw"] for w in ws[i:j + 1]),
                "headDB": round(head, 1),
                "tailDB": round(tail, 1),
            }
        os.remove(episode.wav)

    normalized = [name for name, metadata in preserved.items()
                  if normalize_existing(name, metadata)]

    # The manifest is documentation, not a bundled resource: it stays out of
    # OUT so it never ships inside the app. Keep first-pass phrase clips while
    # the episode families are regenerated.
    combined = {**preserved, **manifest}
    json.dump({
        "note": "Cut from Pattie's own episodes by scripts/cut-pattie-voice.py. "
                "Edges are bounded by nearby silence and softened when speech "
                "runs through a cut. Nothing here is synthesised.",
        "families": previous.get("families", {}),
        "count": len(combined),
        "clips": combined,
    }, open(record, "w"), indent=1)
    print(f"cut {len(manifest)} clips into {OUT}, normalized {len(normalized)} phrase clips, manifest in {record}")
    if hot:
        print("fade-in applied (no silent in-point):", ", ".join(hot))
    still_hot = [n for n, m in manifest.items()
                 if m["headDB"] > HOT_EDGE_DB or m["tailDB"] > HOT_EDGE_DB]
    print("edges still landing in speech:", still_hot or "none")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
