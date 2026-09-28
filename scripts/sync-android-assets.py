#!/usr/bin/env python3
"""Copy shared Pattie content and artwork into the Android app bundle."""

from __future__ import annotations

import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ANDROID_ASSETS = ROOT / "android/app/src/main/assets"
VOICE_SOURCE = ROOT / "IronSplits/Resources/PattieVoice"
VOICE_TARGET = ANDROID_ASSETS / "pattie-voice"


def main() -> None:
    ANDROID_ASSETS.mkdir(parents=True, exist_ok=True)
    for name in ("ask-pattie.json", "pointers.json", "pattie-voice.json"):
        shutil.copy2(ROOT / "docs" / name, ANDROID_ASSETS / name)

    VOICE_TARGET.mkdir(parents=True, exist_ok=True)
    for source in VOICE_SOURCE.glob("*.m4a"):
        shutil.copy2(source, VOICE_TARGET / source.name)

    shutil.copy2(
        ROOT / "IronSplits/Assets.xcassets/pattie-profile.imageset/pattie-profile.jpg",
        ANDROID_ASSETS / "pattie-profile.jpg",
    )
    print("Android Pattie assets synchronised")


if __name__ == "__main__":
    main()
