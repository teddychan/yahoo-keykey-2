# 三代 table: characters matched under a code they do not decompose to

**Date:** 2026-07-25
**Issue:** [#62](https://github.com/teddychan/yahoo-keykey-2/issues/62)
**Status:** Fixed

## Report

Typing `人一弓口` offers 含, whose code is `人戈弓口` — the 反查 hint on the same
row even says so. `人一弓口` is 何's code; 含 should not answer to it.

## Investigation

`CangjieTable.characters(matching:)` is an **exact** dictionary lookup when the
code has no `*`, so the matcher is not at fault — the table data is.

| Table | entries for `omnr` (人一弓口) | codes for 含 |
| --- | --- | --- |
| `Resources/cangjie.txt` (五代, default) | 何 | `oinr` only |
| `Resources/cangjie-yahoo.txt` (三代) | 何, **含**, one PUA char | `oinr` **and `omnr`** |

So the bug reproduces **only in 三代倉頡 (Yahoo KeyKey 相容)**; 五代 is clean and
was verified as such.

### Root cause

`cangjie-yahoo.txt` is a faithful conversion of Yahoo's `cj-ext.cin`, and the
defect is in that upstream file. Its own header says what it is:

> 倉頡（大字集） … supplied by CNS11643 to have around 70,000 Chinese characters.
> This work is based on opendesktop.org.tw's cj.cin file and merged by yylin and b6s.

It is a **merge that never deduplicated**:

- lines 1–13,170 — the curated base table, code-sorted, exactly one code per
  character (13,170 lines, 13,170 characters);
- lines 13,171–82,808 — a CNS11643/HKSCS dump appended verbatim, unsorted.

800 characters appear in both. For **794** of them the dump supplies a *different*
code, which is what pollutes the candidate list (含 as 今口 = `omnr`; 跌 `rvhqo`
vs `rmhqo`; 阪 `nlme` vs `nlhe`; 養 `tomav` vs `toiav`). The remaining 6, plus one
more pair, are exact repeats that made a code list the same character twice.

The base section is the trustworthy one: across the 794 conflicts its code agrees
with the independent 五代 table **669** times, the dump's code only **40**.

## Fix

Data, not code — matching an exact code is correct behaviour. Two rules applied
once to `Resources/cangjie-yahoo.txt`:

1. **Base wins.** Drop every appended-section line that re-encodes a character the
   curated base section already has. Characters are compared under Unicode
   canonical equivalence (NFC) — the way `Character` compares in Swift — so a
   CJK-compatibility codepoint counts as the same character. *(1,113 lines)*
2. **No duplicate character within a code**, among the entries that survive
   `CangjieTable.isRenderableCJK`. Keeps the unified codepoint, drops the
   U+F900–FAFF compatibility twin. *(2 lines: 嗀 U+FA0D, 兀 U+FA0C)*

1,115 of 82,808 lines removed. **No character became unreachable** — every one
keeps its curated base code; the only codepoints that disappear are four
compatibility ideographs (龜 U+F907, 兀 U+FA0C, 嗀 U+FA0D, 慨 U+FA3E) whose
unified forms remain under the same codes.

### Reproduce

After the extraction command in `Resources/CANGJIE-DATA-LICENSE.txt`:

```python
import unicodedata
src = 'Resources/cangjie-yahoo.txt'
raw = open(src, encoding='utf-8').read()
tail = raw.endswith('\n')
lines = raw.split('\n')[:-1] if tail else raw.split('\n')

def renderable(ch):                     # mirrors CangjieTable.isRenderableCJK
    if len(ch) != 1: return False
    v = ord(ch)
    return (0x4E00 <= v <= 0x9FFF or 0x3400 <= v <= 0x4DBF or 0xF900 <= v <= 0xFAFF
            or 0x3000 <= v <= 0x303F or 0xFE30 <= v <= 0xFE4F
            or 0xFF00 <= v <= 0xFFEF or 0x2010 <= v <= 0x2027)

# Rule 1 — the curated base table is the leading run of non-decreasing codes.
bound, prev = 0, None
for i, l in enumerate(lines):
    p = l.split('\t')
    if len(p) < 2: continue
    if prev is not None and p[0] < prev: break
    prev, bound = p[0], i + 1
base = {unicodedata.normalize('NFC', l.split('\t')[1])
        for l in lines[:bound] if len(l.split('\t')) >= 2}
step1 = [l for i, l in enumerate(lines)
         if i < bound or len(l.split('\t')) < 2
         or unicodedata.normalize('NFC', l.split('\t')[1]) not in base]

# Rule 2 — among entries that actually load, keep one character per code.
seen, drop = {}, set()
for i, l in enumerate(step1):
    p = l.split('\t')
    if len(p) < 2 or not renderable(p[1]): continue
    key = (p[0], unicodedata.normalize('NFC', p[1]))
    if key in seen:
        j = seen[key]
        if 0xF900 <= ord(step1[j].split('\t')[1]) <= 0xFAFF and not 0xF900 <= ord(p[1]) <= 0xFAFF:
            drop.add(j); seen[key] = i          # prefer the unified codepoint
        else:
            drop.add(i)
    else:
        seen[key] = i

final = [l for i, l in enumerate(step1) if i not in drop]
open(src, 'w', encoding='utf-8').write('\n'.join(final) + ('\n' if tail else ''))
```

## Tests

`Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/YahooCangjieTableTests.swift`:

- the reported case and three more conflicts — the wrong code no longer matches,
  the real code still does;
- 五代 matches 含 only under `oinr` (guards a future table refresh);
- no code bucket lists the same character twice.

The existing 三代-vs-五代 decomposition and native-candidate-order tests still
pass, so the curated table and Yahoo's candidate order are untouched.

## Not done

- **The 五代 table** keeps one compatibility-ideograph pair (蘒 U+8612 / U+FA20
  under `thdu`) — cosmetic, in a third-party table, and outside this report.
- **457 appended-only characters** carry more than one code among themselves.
  They are rare CNS characters with no curated entry to prefer, so there is no
  basis for choosing; they do not affect the common typing path.
- **`simplex-yahoo.txt`** was checked and is clean: fully sorted, no duplicates,
  no appended dump.
