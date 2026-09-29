#!/usr/bin/env python3
"""Copy shared Pattie content and artwork into the Android app bundle."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ANDROID_ASSETS = ROOT / "android/app/src/main/assets"
VOICE_SOURCE = ROOT / "IronSplits/Resources/PattieVoice"
VOICE_TARGET = ANDROID_ASSETS / "pattie-voice"
ANDROID_DRAWABLES = ROOT / "android/app/src/main/res/drawable-nodpi"
XCASSETS = ROOT / "IronSplits/Assets.xcassets"
# Companion poses draw at 120dp; 480px covers xxxhdpi without shipping 1.5MB PNGs.
ARTWORK = {"pattie-finish": 1400, **{f"pattie-pet-{pose}": 480 for pose in (
    "bike", "celebrate", "coach", "dance", "encourage", "idle", "run", "shoes", "swim")}}


def main() -> None:
    ANDROID_ASSETS.mkdir(parents=True, exist_ok=True)
    for name in ("ask-pattie.json", "pointers.json", "pattie-voice.json"):
        shutil.copy2(ROOT / "docs" / name, ANDROID_ASSETS / name)

    VOICE_TARGET.mkdir(parents=True, exist_ok=True)
    for source in VOICE_SOURCE.glob("*.m4a"):
        shutil.copy2(source, VOICE_TARGET / source.name)

    ANDROID_DRAWABLES.mkdir(parents=True, exist_ok=True)
    for name, max_side in ARTWORK.items():
        source = next(p for p in (XCASSETS / f"{name}.imageset").iterdir() if p.suffix in (".png", ".jpg"))
        target = ANDROID_DRAWABLES / (name.replace("-", "_") + source.suffix)
        shutil.copy2(source, target)
        subprocess.run(["sips", "-Z", str(max_side), str(target)], check=True, capture_output=True)
    print("Android Pattie assets synchronised")


if __name__ == "__main__":
    main()
