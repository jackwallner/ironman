#!/usr/bin/env python3
"""Render the Google Play feature graphic from the app's existing icon."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "android/play-assets"
ICON = ASSETS / "icon-512.png"
SOURCE_ICON = ASSETS / "icon-1024.png"
OUTPUT = ASSETS / "feature-graphic.png"
SIZE = (1024, 500)

DEEP = (17, 43, 67)
SURFACE = (255, 255, 255)
INK_SOFT = (223, 232, 239)
SUNRISE = (240, 120, 82)
BLUE = (29, 116, 200)
GREEN = (72, 151, 34)
RED = (230, 63, 36)
FONT = Path("/System/Library/Fonts/Supplemental")


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT / name), size)


def build() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    icon = Image.open(SOURCE_ICON).convert("RGBA")
    icon = icon.resize((512, 512), Image.Resampling.LANCZOS)
    icon.save(ICON, format="PNG", optimize=True)

    image = Image.new("RGB", SIZE, DEEP)
    draw = ImageDraw.Draw(image)

    # Quiet track curves add movement while keeping the app icon and headline clear.
    for offset, color in ((0, (25, 62, 91)), (1, (20, 55, 83)), (2, (18, 49, 76))):
        draw.arc((630 + offset * 9, 10 + offset * 9, 1000, 378 + offset * 9), 198, 319, fill=color, width=2)

    draw.text((64, 50), "IM TRI TRACKER", fill=SURFACE, font=font("Arial Bold.ttf", 25))
    draw.text((64, 115), "Your race.", fill=SURFACE, font=font("Arial Bold.ttf", 67))
    draw.text((64, 191), "Every split.", fill=SURFACE, font=font("Arial Bold.ttf", 67))
    draw.text(
        (68, 290),
        "Full and half-distance results, ranked by split.",
        fill=INK_SOFT,
        font=font("Arial.ttf", 24),
    )

    disciplines = (("SWIM", BLUE), ("BIKE", GREEN), ("RUN", RED))
    x = 70
    for label, color in disciplines:
        draw.ellipse((x, 384, x + 14, 398), fill=color)
        draw.text((x + 23, 379), label, fill=INK_SOFT, font=font("Arial Bold.ttf", 16))
        x += 125

    card_bounds = (632, 84, 960, 412)
    draw.rounded_rectangle(card_bounds, radius=28, fill=SURFACE)
    draw.text((666, 111), "SPLIT RANKINGS", fill=DEEP, font=font("Arial Bold.ttf", 17))
    for index, (label, color, note) in enumerate(
        (("SWIM", BLUE, "Time and place"), ("BIKE", GREEN, "Time and place"), ("RUN", RED, "Time and place"), ("FINISH", DEEP, "Overall result"))
    ):
        y = 157 + index * 58
        draw.ellipse((668, y + 7, 684, y + 23), fill=color)
        draw.text((700, y), label, fill=DEEP, font=font("Arial Bold.ttf", 16))
        draw.text((700, y + 22), note, fill=(80, 98, 116), font=font("Arial.ttf", 14))
        if index < 3:
            draw.line((668, y + 49, 925, y + 49), fill=(221, 228, 234), width=1)

    ImageDraw.Draw(image).rounded_rectangle((64, 446, 960, 451), radius=2, fill=(38, 69, 95))
    ImageDraw.Draw(image).rounded_rectangle((64, 446, 249, 451), radius=2, fill=SUNRISE)
    image.save(OUTPUT, format="PNG", optimize=True)
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({SIZE[0]}x{SIZE[1]})")


if __name__ == "__main__":
    build()
