#!/usr/bin/env python3
"""Generate Resources/pinyin-zhuyin.txt (pinyin<TAB>zhuyin, one syllable per line).

Source of truth for COVERAGE: the distinct toneless zhuyin syllables in
Resources/data.txt (the McBopomofo LM). Each zhuyin syllable is converted to
Hanyu Pinyin by rule. ü-syllables are emitted under their `v` spelling
(lv, nv, lve, nve, ...), the standard IME convention.

Run AFTER tools/build-lm.sh has produced Resources/data.txt.
Usage: python3 tools/build-pinyin-map.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "Resources", "data.txt")
OUT = os.path.join(ROOT, "Resources", "pinyin-zhuyin.txt")

TONES = "ˊˇˋ˙"  # 2nd, 3rd, 4th, neutral; 1st tone is unmarked

INITIALS = {
    "ㄅ": "b", "ㄆ": "p", "ㄇ": "m", "ㄈ": "f",
    "ㄉ": "d", "ㄊ": "t", "ㄋ": "n", "ㄌ": "l",
    "ㄍ": "g", "ㄎ": "k", "ㄏ": "h",
    "ㄐ": "j", "ㄑ": "q", "ㄒ": "x",
    "ㄓ": "zh", "ㄔ": "ch", "ㄕ": "sh", "ㄖ": "r",
    "ㄗ": "z", "ㄘ": "c", "ㄙ": "s",
}
MEDIALS = {"ㄧ": "i", "ㄨ": "u", "ㄩ": "v"}  # v == ü internally
FINALS = {
    "ㄚ": "a", "ㄛ": "o", "ㄜ": "e", "ㄝ": "ê",
    "ㄞ": "ai", "ㄟ": "ei", "ㄠ": "ao", "ㄡ": "ou",
    "ㄢ": "an", "ㄣ": "en", "ㄤ": "ang", "ㄥ": "eng",
    "ㄦ": "er",
}

# Every legal zhuyin component (used to filter out non-zhuyin pseudo-keys).
ZHUYIN_CHARS = set(INITIALS) | set(MEDIALS) | set(FINALS)


def zhuyin_to_pinyin(z):
    """Convert one toneless zhuyin syllable to Hanyu Pinyin. Returns None if unmappable."""
    chars = list(z)
    initial = ""
    if chars and chars[0] in INITIALS:
        initial = INITIALS[chars[0]]
        chars = chars[1:]
    medial = ""
    if chars and chars[0] in MEDIALS:
        medial = MEDIALS[chars[0]]
        chars = chars[1:]
    final = ""
    if chars and chars[0] in FINALS:
        final = FINALS[chars[0]]
        chars = chars[1:]
    if chars:
        return None  # leftover -> unmappable

    if initial in ("zh", "ch", "sh", "r", "z", "c", "s") and not medial and not final:
        return initial + "i"
    if not initial and not medial and final == "er":
        return "er"

    if medial == "i":
        if not final:
            return (initial + "i") if initial else "yi"
        # ㄧㄛ (io) is the standalone interjection 唷/喲 -> "yo"; it never takes an
        # initial and must NOT be confused with ㄩㄥ (iong/yong).
        if final == "o":
            return "yo"
        # For en/eng/ou after an initial, the pinyin rime already carries the
        # medial (nin/ning/niu), so don't prepend another "i".
        contracted = {"en": "in", "eng": "ing", "ou": "iu"}
        mapped = contracted.get(final, final)
        if initial:
            return _tidy(initial + mapped) if final in contracted else _tidy(initial + "i" + mapped)
        yf = {"a": "ya", "e": "ye", "ê": "ye", "ai": "yai",
              "ao": "yao", "an": "yan", "ang": "yang", "ou": "you",
              "in": "yin", "ing": "ying", "iu": "you",
              "eng": "ying", "en": "yin"}
        return _tidy(yf.get(mapped, "y" + mapped))

    if medial == "u":
        if not final:
            return (initial + "u") if initial else "wu"
        # For ei/en/eng after an initial, the pinyin rime already carries the
        # medial (dui/dun/dong), so don't prepend another "u".
        contracted = {"ei": "ui", "en": "un", "eng": "ong"}
        mapped = contracted.get(final, final)
        if initial:
            return _tidy(initial + mapped) if final in contracted else _tidy(initial + "u" + mapped)
        wf = {"a": "wa", "o": "wo", "ai": "wai", "ei": "wei", "an": "wan",
              "en": "wen", "ang": "wang", "eng": "weng", "ui": "wei",
              "un": "wen", "ong": "weng"}
        return _tidy(wf.get(mapped, "w" + mapped))

    if medial == "v":
        if not final:
            if initial in ("j", "q", "x"):
                return initial + "u"
            if initial in ("n", "l"):
                return initial + "v"
            return "yu"
        mapped = {"en": "n", "eng": "iong"}.get(final, final)
        if initial in ("j", "q", "x"):
            return _tidy(initial + "u" + mapped) if mapped != "iong" else initial + "iong"
        if initial in ("n", "l"):
            return _tidy(initial + "v" + mapped)
        yf = {"ê": "yue", "e": "yue", "an": "yuan", "n": "yun", "iong": "yong"}
        return _tidy(yf.get(mapped, "yu" + mapped))

    if not final:
        return initial or None
    return _tidy(initial + final)


def _tidy(s):
    return "e" if s == "ê" else s.replace("ê", "e")


def is_zhuyin_syllable(s):
    """True only if every char in the (tone-stripped) syllable is a zhuyin component."""
    return bool(s) and all(ch in ZHUYIN_CHARS for ch in s)


def collect_syllables(path):
    """Return {toneless_zhuyin_syllable: occurrence_count} for real zhuyin only."""
    syl = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(" ")
            if len(parts) != 3:
                continue
            key = parts[0]
            for tone in TONES:
                key = key.replace(tone, "")
            for s in key.split("-"):
                # Only real zhuyin syllables; skip punctuation/ASCII pseudo-keys.
                if is_zhuyin_syllable(s):
                    syl[s] = syl.get(s, 0) + 1
    return syl


def main():
    if not os.path.exists(DATA):
        sys.exit("ERROR: Resources/data.txt missing; run tools/build-lm.sh first")
    counts = collect_syllables(DATA)
    zsyls = sorted(counts)
    rows = {}          # pinyin -> chosen zhuyin
    shadowed = []      # (pinyin, kept_zhuyin, dropped_zhuyin) collisions
    unmapped = []
    for z in zsyls:
        py = zhuyin_to_pinyin(z)
        if py is None:
            unmapped.append(z)
            continue
        prev = rows.get(py)
        if prev is not None and prev != z:
            # Two distinct zhuyin syllables share one real pinyin spelling
            # (e.g. ㄜ vs ㄝ both -> "e"). Keep the more frequent reading; the
            # rarer/colloquial one is unreachable via pinyin (candidate list
            # still surfaces it under the winning key).
            keep, drop = (prev, z) if counts[prev] >= counts[z] else (z, prev)
            shadowed.append((py, keep, drop))
            rows[py] = keep
        else:
            rows[py] = z
    if unmapped:
        sys.stderr.write("WARN: unmapped zhuyin syllables: %s\n" % " ".join(unmapped))
    for py, keep, drop in shadowed:
        sys.stderr.write("NOTE: pinyin '%s' kept %s (%d), shadowed %s (%d)\n" % (
            py, keep, counts[keep], drop, counts[drop]))
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# pinyin<TAB>zhuyin  (generated by tools/build-pinyin-map.py; v == ü)\n")
        for py in sorted(rows):
            f.write("%s\t%s\n" % (py, rows[py]))
    print("Wrote %s (%d syllables, %d unmapped, %d shadowed)" % (
        OUT, len(rows), len(unmapped), len(shadowed)))


if __name__ == "__main__":
    main()
