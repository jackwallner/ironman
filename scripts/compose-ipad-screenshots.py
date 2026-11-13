#!/usr/bin/env python3
"""Compose the 13-inch iPad App Store frames (2064x2752) from raw captures.

Same look as the live iPhone set: pale blue gradient, one large navy header,
the literal screen in a black bezel. Raw captures come from IPadLayoutUITests
(`<tag>-<name>.png` attachments exported by gh-sim).

  compose-ipad-screenshots.py <raw-dir> <out-dir>
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2064, 2752
FRAMES = [
    ("01_find-every-race-by-name", "Find every race by your name", "portrait-locker"),
    ("02_see-every-split-in-one-view", "See every split in one view", "portrait-rankings"),
    ("03_see-where-you-found-time", "See where you found time", "portrait-rankings-run"),
    ("04_turn-your-races-into-a-book", "Turn your races into a book", "portrait-racebook"),
    ("05_get-tips-for-your-next-race", "Get tips for your next race", "portrait-tips"),
]
INK = (11, 30, 58)
TOP, BOTTOM = (236, 241, 249), (214, 224, 238)


def font(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
    f.set_variation_by_name("Regular")
    return f


def wrap(draw: ImageDraw.ImageDraw, text: str, f, width: int) -> list[str]:
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=f) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    return lines + [cur]


def compose(raw: Path, header: str, out: Path) -> None:
    img = Image.new("RGB", (W, H))
    px = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        px.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))

    f = font(160)
    lines = wrap(px, header, f, W - 240)
    if len(lines) == 2:  # balance the two lines instead of leaving an orphan
        width = W - 240
        while width > 600 and len(wrap(px, header, f, width - 20)) == 2:
            width -= 20
        lines = wrap(px, header, f, width)
    assert len(lines) <= 2, header
    y = 150
    for line in lines:
        px.text((W / 2, y), line, font=f, fill=INK, anchor="ma")
        y += 190

    shot = Image.open(raw).convert("RGB")
    bezel, radius = 34, 110
    sw = 1500
    sh = round(sw * shot.height / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    dw, dh = sw + 2 * bezel, sh + 2 * bezel
    x, top = (W - dw) // 2, 600
    assert top + dh <= H - 60, (top + dh)

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x, top + 30, x + dw, top + dh + 30), radius, fill=(8, 20, 40, 70))
    img.paste(Image.alpha_composite(img.convert("RGBA"),
                                    shadow.filter(ImageFilter.GaussianBlur(40))).convert("RGB"))
    body = Image.new("RGB", (dw, dh), (10, 10, 12))
    mask = Image.new("L", (dw, dh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, dw, dh), radius, fill=255)
    img.paste(body, (x, top), mask)
    smask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(smask).rounded_rectangle((0, 0, sw, sh), radius - bezel, fill=255)
    img.paste(shot, (x + bezel, top + bezel), smask)
    img.save(out, "PNG", optimize=True)


def main() -> None:
    raw, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    for name, header, key in FRAMES:
        src = next(raw.glob(f"{key}_0_*.png"), None) or raw / f"{key}.png"
        compose(src, header, out / f"{name}.png")
        print("wrote", out / f"{name}.png")


if __name__ == "__main__":
    main()
