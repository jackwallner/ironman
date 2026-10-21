#!/usr/bin/env python3
"""Validate Google Play listing copy under android/play-assets/metadata/android.

Checks every locale folder for Play's limits (title 30, short 80, full 4000),
the house rules (no em dashes, no prices, no Apple wording, no promo words in
the title), the IM Tri Tracker brand rules (brand in every title, no event
trademarks or distance shorthand) and the required lines: the Google Play
purchase paragraph, the policy links and, in every non-English locale, the
sentence saying the app itself is in English. Exit 1 on any failure.

Usage: scripts/validate-play-listing.py [--root DIR]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "android/play-assets/metadata/android"
LIMITS = {"title.txt": 30, "short_description.txt": 80, "full_description.txt": 4000}
BRAND = "IM Tri Tracker"
# Play language codes accepted by the Publishing API (fastlane supply list).
PLAY_LANGS = set(
    "af am ar az-AZ be bg bn-BD ca cs-CZ da-DK de-DE el-GR en-AU en-CA en-GB en-IN "
    "en-SG en-US en-ZA es-419 es-ES es-US et eu-ES fa fi-FI fil fr-CA fr-FR gl-ES "
    "hi-IN hr hu-HU hy-AM id is-IS it-IT iw-IL ja-JP ka-GE km-KH kn-IN ko-KR ky-KG "
    "lo-LA lt lv mk-MK ml-IN mn-MN mr-IN ms ms-MY my-MM ne-NP nl-NL no-NO pl-PL "
    "pt-BR pt-PT rm ro ru-RU si-LK sk sl sr sv-SE sw ta-IN te-IN th tr-TR uk vi "
    "zh-CN zh-HK zh-TW zu".split()
)
# The sentence each non-English listing uses to say the app is in English,
# keyed by language (the part of the locale before the dash).
ENGLISH_NOTICE = {
    "de": "Die App selbst ist auf Englisch",
    "fr": "L'application elle-même est en anglais",
    "es": "La app está en inglés",
    "pt-BR": "O app está em inglês",
    "pt-PT": "A aplicação está em inglês",
    "it": "L'app è in inglese",
    "nl": "De app zelf is in het Engels",
    "sv": "Själva appen är på engelska",
    "no": "Selve appen er på engelsk",
    "da": "Selve appen er på engelsk",
    "fi": "Itse sovellus on englanninkielinen",
    "pl": "Sama aplikacja jest w języku angielskim",
    "cs": "Samotná aplikace je v angličtině",
    "sk": "Samotná aplikácia je v angličtine",
    "sl": "Aplikacija je v angleščini",
    "hr": "Sama aplikacija je na engleskom jeziku",
    "hu": "Maga az alkalmazás angol nyelvű",
    "ro": "Aplicația în sine este în limba engleză",
    "el": "Η ίδια η εφαρμογή είναι στα αγγλικά",
    "tr": "Uygulamanın kendisi İngilizcedir",
    "ru": "Само приложение на английском языке",
    "uk": "Сам застосунок англійською мовою",
    "ar": "التطبيق نفسه باللغة الإنجليزية",
    "iw": "האפליקציה עצמה באנגלית",
    "hi": "ऐप खुद अंग्रेज़ी में है",
    "bn": "অ্যাপটি নিজে ইংরেজিতে",
    "mr": "ॲप स्वतः इंग्रजीत आहे",
    "ta": "ஆப் ஆங்கிலத்தில் உள்ளது",
    "te": "యాప్ ఇంగ్లీష్‌లో ఉంటుంది",
    "kn": "ಆ್ಯಪ್ ಇಂಗ್ಲಿಷ್‌ನಲ್ಲಿದೆ",
    "ml": "ആപ്പ് ഇംഗ്ലീഷിലാണ്",
    "id": "Aplikasinya sendiri berbahasa Inggris",
    "ms": "Aplikasi ini dalam bahasa Inggeris",
    "th": "ตัวแอปเป็นภาษาอังกฤษ",
    "vi": "Bản thân ứng dụng dùng tiếng Anh",
    "ja": "アプリ自体の表示言語は英語です",
    "ko": "앱 자체는 영어로 제공됩니다",
    "zh-CN": "应用本身为英文界面",
    "zh-TW": "App 本身為英文介面",
    "zh-HK": "App 本身為英文介面",
    "ca": "L'aplicació en si està en anglès",
}
TITLE_BANNED = re.compile(r"\b(free|best|top|#1|new|sale)\b", re.I)
PRICE = re.compile(r"[$€£¥₹]\s?\d|\d[.,]\d\d\s?(?:€|zł|kr|lei|Kč|₺|₽|₴)")
APPLE = re.compile(r"Apple|App Store|iPhone|iCloud|Apple Watch", re.I)
# Event trademarks and distance shorthand never appear as keywords.
TRADEMARK = re.compile(r"IRONMAN|Ironman|M-?DOT|140\.6|70\.3")
URL_OK = re.compile(r"https://jackwallner\.github\.io/\S+")
LINKS = ("privacy-policy.html", "terms.html", "support.html")


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8").strip() if p.exists() else ""


def notice_for(loc: str) -> str | None:
    if loc.startswith("en"):
        return None
    return ENGLISH_NOTICE.get(loc) or ENGLISH_NOTICE.get(loc.split("-")[0])


def check_file(name: str, text: str, limit: int) -> list[str]:
    errs: list[str] = []
    n = len(text)
    if n == 0 or n > limit:
        errs.append(f"{name} {n}/{limit}")
    if "—" in text:
        errs.append(f"{name} has an em dash")
    if re.search("[­​﻿]", text):
        errs.append(f"{name} has an invisible character")
    if m := PRICE.search(text):
        errs.append(f"{name} looks like it has a price: {m.group(0)!r}")
    if m := APPLE.search(URL_OK.sub("", text)):
        errs.append(f"{name} mentions Apple wording: {m.group(0)!r}")
    if m := TRADEMARK.search(URL_OK.sub("", text)):
        errs.append(f"{name} uses an event trademark or distance shorthand: {m.group(0)!r}")
    if name != "full_description.txt" and "\n" in text:
        errs.append(f"{name} spans lines")
    return errs


def check(locale_dir: Path) -> list[str]:
    errs: list[str] = []
    loc = locale_dir.name
    if loc not in PLAY_LANGS:
        errs.append(f"unknown Play language code {loc}")
    for name, limit in LIMITS.items():
        if not (locale_dir / name).exists():
            errs.append(f"missing {name}")
            continue
        errs += check_file(name, read(locale_dir / name), limit)
    title = read(locale_dir / "title.txt")
    full = read(locale_dir / "full_description.txt")
    if not title.startswith(BRAND):
        errs.append(f"title does not lead with {BRAND!r}: {title!r}")
    if TITLE_BANNED.search(title):
        errs.append(f"title has a promo word: {title!r}")
    if "Google Play" not in full:
        errs.append("full description lacks the Google Play purchase paragraph")
    errs += [f"full description lacks the {link} link" for link in LINKS if link not in full]
    notice = notice_for(loc)
    if not loc.startswith("en") and notice is None:
        errs.append("no English-app notice is defined for this language")
    elif notice and notice not in full:
        errs.append(f"full description lacks the English-app notice {notice!r}")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=ROOT)
    args = ap.parse_args()
    bad = 0
    dirs = sorted(d for d in args.root.iterdir() if d.is_dir())
    for d in dirs:
        errs = check(d)
        t, s, f = (read(d / n) for n in LIMITS)
        status = "OK " if not errs else "BAD"
        print(f"{status} {d.name:7} t{len(t):>3} s{len(s):>3} f{len(f):>5}  {t}")
        for e in errs:
            print(f"      - {e}")
        bad += bool(errs)
    print(f"\n{len(dirs)} locales, {bad} with problems")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
