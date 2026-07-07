# Pinyin (拼音) Input Method Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a phrase/sentence Pinyin input method to Yahoo KeyKey 2 that composes Traditional Chinese from toneless Hanyu Pinyin using a best-path walk over the existing McBopomofo zhuyin language model.

**Architecture:** A new front-end (syllable table + segmenter) converts pinyin → toneless zhuyin *readings*; a reading-source-agnostic reading grid + Viterbi-style `Walker` picks the best segmentation + characters over a **separate, lazily-built** tone-stripped index of the existing LM. A composing-buffer `PinyinEngine` drives an editable multi-node composition. Cangjie/Simplex code paths are untouched; the heavy Pinyin index is reference-counted so it loads only while Pinyin is active.

**Tech Stack:** Swift 5 (language mode), SwiftPM package `KeyKeyEngine`, InputMethodKit host app, XCTest. Data files are plain UTF-8 text.

**Design spec:** [`docs/superpowers/specs/2026-07-06-pinyin-input-method-design.md`](../specs/2026-07-06-pinyin-input-method-design.md)

---

## Execution note on phasing

Delivery is **phased** (per the spec) with a **review checkpoint at each phase boundary**:

- **Phase 1 (Tasks 1–7)** is the headless engine, fully specified below with complete TDD steps and code. **This is the immediate execution target.**
- **Phase 2 (Tasks 8–12)** wires IMK/UX and packaging. Its tasks list exact files, signatures, plist keys, and build-script edits. Line-level step detail for the interactive IMK wiring is finalized at the Phase 1→2 boundary, once the Phase 1 engine API is real and verified (avoids drift).
- **Phase 3 (Tasks 13–14)** is polish + release wiring.

Do not start Phase 2 until Phase 1 is merged and green.

---

## File Structure

**New — engine package (`Packages/KeyKeyEngine/Sources/KeyKeyEngine/`):**
- `PinyinSyllableTable.swift` — loads `pinyin-zhuyin.txt`; valid-syllable set + `zhuyin(forSyllable:)`.
- `PinyinSegmenter.swift` — latin string → `(syllables, tail)`.
- `TonelessLanguageModelIndex.swift` — separate lazy index: tone-stripped key → deduped unigrams; `maxSpanLength`.
- `Walker.swift` — `WalkNode`, `Walker` (bounded best-path DP).
- `PinyinEngine.swift` — composing-buffer engine (public API for cursor/candidates/commit).

**New — data + tooling:**
- `Resources/pinyin-zhuyin.txt` — checked-in syllable map (with `v`=`ü` keys).
- `tools/build-pinyin-map.py` — generator (provenance/regeneration).

**New — tests (`Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/`):**
- `PinyinSyllableTableTests.swift`, `PinyinSegmenterTests.swift`,
  `TonelessLanguageModelIndexTests.swift`, `WalkerTests.swift`, `PinyinEngineTests.swift`,
  `RealPinyinWalkerTests.swift` (golden, skips if `data.txt` absent).

**Modified — app (`App/`):**
- `InputEngine.swift` — add `PhraseComposingEngine` protocol + `extension PinyinEngine`.
- `InputController.swift` — register Pinyin module; branch `PhraseComposingEngine` before the existing candidate block; acquire/release the Pinyin index on mode switch + deinit.
- `SharedResources.swift` — reference-counted lazy `TonelessLanguageModelIndex` accessor.
- `Info.plist` — add the `Pinyin` input mode.

**Modified — build:**
- `tools/build-app.sh` — copy `pinyin-zhuyin.txt`; add new `App/*.swift` to the `swiftc` source list (only if new App files are added; none are in this plan — the changes are edits to existing App files).

---

# PHASE 1 — Headless engine

Run all tests from the package dir. Convenience:
```bash
cd Packages/KeyKeyEngine
swift test 2>&1 | tail -20
```

---

### Task 1: Pinyin→zhuyin syllable map (data + generator)

**Files:**
- Create: `tools/build-pinyin-map.py`
- Create: `Resources/pinyin-zhuyin.txt`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/PinyinSyllableTableTests.swift` (spot-checks here; full validation in Task 2's real-table test)

The map is generated from the **distinct toneless zhuyin syllables actually present in the LM** (`Resources/data.txt`), so coverage always matches the model. Each zhuyin syllable is converted to Hanyu Pinyin by a deterministic component function, and `ü`-syllables are additionally keyed under their `v` spelling.

- [ ] **Step 1: Write the generator**

Create `tools/build-pinyin-map.py`:

```python
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

    # Standalone syllabic consonant: ㄓ alone -> zhi, etc.
    if initial in ("zh", "ch", "sh", "r", "z", "c", "s") and not medial and not final:
        return initial + "i"
    # ㄦ alone -> er
    if not initial and not medial and final == "er":
        return "er"

    # --- medial ㄧ (i) ---
    if medial == "i":
        if not final:
            return (initial + "i") if initial else "yi"
        mapped = {"o": "ong", "en": "in", "eng": "ing", "ou": "iu"}.get(final, final)
        if initial:
            return _tidy(initial + "i" + mapped)
        yf = {"a": "ya", "o": "yong", "e": "ye", "ê": "ye", "ai": "yai",
              "ao": "yao", "an": "yan", "ang": "yang", "ou": "you",
              "in": "yin", "ing": "ying", "ong": "yong", "iu": "you",
              "eng": "ying", "en": "yin"}
        return _tidy(yf.get(mapped, "y" + mapped))

    # --- medial ㄨ (u) ---
    if medial == "u":
        if not final:
            return (initial + "u") if initial else "wu"
        mapped = {"ei": "ui", "en": "un", "eng": "ong"}.get(final, final)
        if initial:
            return _tidy(initial + "u" + mapped)
        wf = {"a": "wa", "o": "wo", "ai": "wai", "ei": "wei", "an": "wan",
              "en": "wen", "ang": "wang", "eng": "weng", "ui": "wei",
              "un": "wen", "ong": "weng"}
        return _tidy(wf.get(mapped, "w" + mapped))

    # --- medial ㄩ (ü / v) ---
    if medial == "v":
        if not final:
            if initial in ("j", "q", "x"):
                return initial + "u"
            if initial in ("n", "l"):
                return initial + "v"
            return "yu"
        mapped = {"en": "n", "eng": "iong"}.get(final, final)  # ün->un, üeng->iong
        if initial in ("j", "q", "x"):
            return _tidy(initial + "u" + mapped) if mapped != "iong" else initial + "iong"
        if initial in ("n", "l"):
            return _tidy(initial + "v" + mapped)
        yf = {"ê": "yue", "e": "yue", "an": "yuan", "n": "yun", "iong": "yong"}
        return _tidy(yf.get(mapped, "yu" + mapped))

    # --- no medial ---
    if not final:
        return initial or None
    return _tidy(initial + final)


def _tidy(s):
    # ê stands alone (or after y as 'ye'); elsewhere written 'e'.
    return "e" if s == "ê" else s.replace("ê", "e")


def collect_syllables(path):
    syl = set()
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
                if s:
                    syl.add(s)
    return syl


def main():
    if not os.path.exists(DATA):
        sys.exit("ERROR: Resources/data.txt missing; run tools/build-lm.sh first")
    zsyls = sorted(collect_syllables(DATA))
    rows = {}          # pinyin -> zhuyin
    unmapped = []
    for z in zsyls:
        py = zhuyin_to_pinyin(z)
        if py is None:
            unmapped.append(z)
            continue
        rows[py] = z
    if unmapped:
        sys.stderr.write("WARN: unmapped zhuyin syllables: %s\n" % " ".join(unmapped))
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# pinyin<TAB>zhuyin  (generated by tools/build-pinyin-map.py; v == ü)\n")
        for py in sorted(rows):
            f.write("%s\t%s\n" % (py, rows[py]))
    print("Wrote %s (%d syllables, %d unmapped)" % (OUT, len(rows), len(unmapped)))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Generate the table (requires data.txt)**

Run:
```bash
[ -f Resources/data.txt ] || tools/build-lm.sh
python3 tools/build-pinyin-map.py
```
Expected: `Wrote …/Resources/pinyin-zhuyin.txt (N syllables, 0 unmapped)` with N ≈ 400+. If unmapped > 0, inspect the reported syllables and fix `zhuyin_to_pinyin` before continuing. Spot-check:
```bash
grep -E "^(hao|ni|wo|men|qu|lv|nve|yu|yue|yuan|zhi|shi|er|hui|you)	" Resources/pinyin-zhuyin.txt
```
Expected rows include: `hao⇥ㄏㄠ`, `ni⇥ㄋㄧ`, `wo⇥ㄨㄛ`, `qu⇥ㄑㄩ`, `lv⇥ㄌㄩ`, `nve⇥ㄋㄩㄝ`, `yu⇥ㄩ`, `yue⇥ㄩㄝ`, `yuan⇥ㄩㄢ`, `zhi⇥ㄓ`, `shi⇥ㄕ`, `er⇥ㄦ`, `hui⇥ㄏㄨㄟ`, `you⇥ㄧㄡ`.

- [ ] **Step 3: Commit the generator + generated table**

```bash
git add tools/build-pinyin-map.py Resources/pinyin-zhuyin.txt
git commit -m "feat(pinyin): generate pinyin-zhuyin syllable map from LM"
```

> Note: `data.txt` is intentionally not committed (clean-checkout omits it; CI runs `build-lm.sh`). `pinyin-zhuyin.txt` IS committed because it is small and static.

---

### Task 2: `PinyinSyllableTable`

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/PinyinSyllableTable.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/PinyinSyllableTableTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PinyinSyllableTableTests.swift`:

```swift
import XCTest
@testable import KeyKeyEngine

final class PinyinSyllableTableTests: XCTestCase {
    func testLoadsSyllablesAndMapsToZhuyin() {
        let table = PinyinSyllableTable(text: """
        # comment
        hao\tㄏㄠ
        ni\tㄋㄧ
        lv\tㄌㄩ
        """)
        XCTAssertTrue(table.isValidSyllable("hao"))
        XCTAssertTrue(table.isValidSyllable("ni"))
        XCTAssertTrue(table.isValidSyllable("lv"))
        XCTAssertFalse(table.isValidSyllable("zzz"))
        XCTAssertEqual(table.zhuyin(forSyllable: "hao"), "ㄏㄠ")
        XCTAssertEqual(table.zhuyin(forSyllable: "lv"), "ㄌㄩ")
        XCTAssertNil(table.zhuyin(forSyllable: "zzz"))
    }

    func testMaxSyllableLengthReflectsData() {
        let table = PinyinSyllableTable(text: "a\tㄚ\nzhuang\tㄓㄨㄤ")
        XCTAssertEqual(table.maxSyllableLength, 6) // "zhuang"
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter PinyinSyllableTableTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'PinyinSyllableTable' in scope`.

- [ ] **Step 3: Implement**

Create `PinyinSyllableTable.swift`:

```swift
import Foundation

/// Maps a Hanyu Pinyin syllable (e.g. "hao") to its toneless zhuyin reading
/// (e.g. "ㄏㄠ"). `ü`-syllables are keyed under their `v` spelling (see the
/// generator, tools/build-pinyin-map.py). Line format: "<pinyin>\t<zhuyin>".
public struct PinyinSyllableTable {
    private var map: [String: String] = [:]
    /// Longest pinyin syllable, so the segmenter can bound its longest-match window.
    public private(set) var maxSyllableLength: Int = 0

    public init(text: String) {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let pinyin = String(parts[0])
            let zhuyin = String(parts[1])
            guard !pinyin.isEmpty, !zhuyin.isEmpty else { continue }
            map[pinyin] = zhuyin
            maxSyllableLength = max(maxSyllableLength, pinyin.count)
        }
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public func isValidSyllable(_ s: String) -> Bool { map[s] != nil }
    public func zhuyin(forSyllable s: String) -> String? { map[s] }
    public var syllableCount: Int { map.count }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter PinyinSyllableTableTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Add a real-table validation test**

Append to `PinyinSyllableTableTests.swift`:

```swift
extension PinyinSyllableTableTests {
    private func tableURL() -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Resources/pinyin-zhuyin.txt")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testRealTableLoadsAndCoversCommonSyllables() throws {
        guard let url = tableURL() else { throw XCTSkip("pinyin-zhuyin.txt not present") }
        let table = try PinyinSyllableTable(contentsOf: url)
        XCTAssertGreaterThan(table.syllableCount, 380)
        for s in ["hao", "ni", "wo", "men", "qu", "lv", "nve", "yu", "yue",
                  "yuan", "zhi", "shi", "er", "hui", "you", "wen", "yun"] {
            XCTAssertTrue(table.isValidSyllable(s), "missing syllable: \(s)")
        }
    }
}
```

- [ ] **Step 6: Run + commit**

Run: `cd Packages/KeyKeyEngine && swift test --filter PinyinSyllableTableTests 2>&1 | tail -20` → PASS.
```bash
git add Packages/KeyKeyEngine/Sources/KeyKeyEngine/PinyinSyllableTable.swift \
        Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/PinyinSyllableTableTests.swift
git commit -m "feat(pinyin): PinyinSyllableTable"
```

---

### Task 3: `PinyinSegmenter`

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/PinyinSegmenter.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/PinyinSegmenterTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PinyinSegmenterTests.swift`:

```swift
import XCTest
@testable import KeyKeyEngine

final class PinyinSegmenterTests: XCTestCase {
    // Minimal syllable set covering the cases under test.
    private let table = PinyinSyllableTable(text: """
    ni\tㄋㄧ
    hao\tㄏㄠ
    wo\tㄨㄛ
    men\tㄇㄣ
    qu\tㄑㄩ
    xi\tㄒㄧ
    xian\tㄒㄧㄢ
    an\tㄢ
    fan\tㄈㄢ
    gan\tㄍㄢ
    fang\tㄈㄤ
    lv\tㄌㄩ
    nve\tㄋㄩㄝ
    """)

    private func seg(_ s: String) -> (syllables: [String], tail: String) {
        PinyinSegmenter(table: table).segment(s)
    }

    func testSimplePhrases() {
        XCTAssertEqual(seg("nihao").syllables, ["ni", "hao"])
        XCTAssertEqual(seg("womenqu").syllables, ["wo", "men", "qu"])
    }

    func testGreedyLongestMatch() {
        XCTAssertEqual(seg("xian").syllables, ["xian"])       // one syllable, not xi+an
        XCTAssertEqual(seg("fangan").syllables, ["fang", "an"]) // greedy: fang+an
    }

    func testApostropheForcesBoundary() {
        XCTAssertEqual(seg("xi'an").syllables, ["xi", "an"])
    }

    func testUpsilonViaV() {
        XCTAssertEqual(seg("lv").syllables, ["lv"])
        XCTAssertEqual(seg("nve").syllables, ["nve"])
    }

    func testTrailingUnparsableTail() {
        let r = seg("nihaoxq")
        XCTAssertEqual(r.syllables, ["ni", "hao"])
        XCTAssertEqual(r.tail, "xq")
    }

    func testEmpty() {
        let r = seg("")
        XCTAssertTrue(r.syllables.isEmpty)
        XCTAssertEqual(r.tail, "")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter PinyinSegmenterTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'PinyinSegmenter' in scope`.

- [ ] **Step 3: Implement**

Create `PinyinSegmenter.swift`:

```swift
import Foundation

/// Splits a latin pinyin string into syllables using greedy longest-match with
/// backtracking against a PinyinSyllableTable. `'` forces a syllable boundary.
/// Any trailing fragment that cannot be parsed is returned as `tail` (kept
/// visible; never dropped, never crashes).
public struct PinyinSegmenter {
    private let table: PinyinSyllableTable
    public init(table: PinyinSyllableTable) { self.table = table }

    public func segment(_ input: String) -> (syllables: [String], tail: String) {
        let scalars = Array(input)
        var syllables: [String] = []
        var i = 0
        let maxLen = max(1, table.maxSyllableLength)
        while i < scalars.count {
            if scalars[i] == "'" { i += 1; continue } // explicit boundary separator
            // Longest match starting at i, not crossing an apostrophe.
            var matched: String? = nil
            var matchLen = 0
            let upper = min(maxLen, scalars.count - i)
            if upper >= 1 {
                for len in stride(from: upper, through: 1, by: -1) {
                    let slice = scalars[i..<(i + len)]
                    if slice.contains("'") { continue }
                    let cand = String(slice)
                    if table.isValidSyllable(cand) { matched = cand; matchLen = len; break }
                }
            }
            if let matched {
                syllables.append(matched)
                i += matchLen
            } else {
                break // remainder is an unparsable tail
            }
        }
        let tail = String(scalars[i...].filter { $0 != "'" })
        return (syllables, tail)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter PinyinSegmenterTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine/Sources/KeyKeyEngine/PinyinSegmenter.swift \
        Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/PinyinSegmenterTests.swift
git commit -m "feat(pinyin): PinyinSegmenter (greedy longest-match + apostrophe)"
```

---

### Task 4: `TonelessLanguageModelIndex`

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/TonelessLanguageModelIndex.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/TonelessLanguageModelIndexTests.swift`

This is a **separate** type; `LanguageModel` is NOT modified (keeps Cangjie/Simplex startup identical).

- [ ] **Step 1: Write the failing test**

Create `TonelessLanguageModelIndexTests.swift`:

```swift
import XCTest
@testable import KeyKeyEngine

final class TonelessLanguageModelIndexTests: XCTestCase {
    // McBopomofo "sorted" format: "<key> <phrase> <score>". Tones: ˊ ˇ ˋ ˙ (1st unmarked).
    private let sample = """
    # format org.openvanilla.mcbopomofo.sorted
    ㄏㄠˇ 好 -3.0
    ㄏㄠˊ 豪 -4.0
    ㄏㄠˋ 號 -3.5
    ㄋㄧˇ 你 -3.2
    ㄋㄧˇ-ㄏㄠˇ 你好 -5.0
    """

    func testTonelessKeyAggregatesAcrossTones() {
        let idx = TonelessLanguageModelIndex(text: sample)
        let unis = idx.unigrams(forKey: "ㄏㄠ")
        let values = Set(unis.map(\.value))
        XCTAssertEqual(values, ["好", "豪", "號"])
    }

    func testCandidatesSortedByScoreDescending() {
        let idx = TonelessLanguageModelIndex(text: sample)
        let unis = idx.unigrams(forKey: "ㄏㄠ")
        XCTAssertEqual(unis.first?.value, "好") // -3.0 is the highest (closest to 0)
    }

    func testMultiSyllablePhraseKey() {
        let idx = TonelessLanguageModelIndex(text: sample)
        XCTAssertEqual(idx.unigrams(forKey: "ㄋㄧ-ㄏㄠ").map(\.value), ["你好"])
    }

    func testMaxSpanLength() {
        let idx = TonelessLanguageModelIndex(text: sample)
        XCTAssertEqual(idx.maxSpanLength, 2) // "ㄋㄧ-ㄏㄠ" = 2 syllables
    }

    func testEmptyLookup() {
        let idx = TonelessLanguageModelIndex(text: sample)
        XCTAssertTrue(idx.unigrams(forKey: "ㄗㄗ").isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter TonelessLanguageModelIndexTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'TonelessLanguageModelIndex' in scope`.

- [ ] **Step 3: Implement**

Create `TonelessLanguageModelIndex.swift`:

```swift
import Foundation

/// A tone-stripped view of the McBopomofo LM, keyed by hyphen-joined TONELESS
/// zhuyin (so toneless pinyin readings can match). Built ONLY when Pinyin is
/// active — never in LanguageModel.init — so Cangjie/Simplex users pay nothing.
///
/// Parses the same "<key> <phrase> <score>" text as LanguageModel, strips the
/// tone marks ˊ ˇ ˋ ˙ (1st tone is already unmarked) from each key, aggregates
/// unigrams that collapse onto the same toneless key (dedup by value, keeping the
/// max score), and stores them sorted by score descending.
public struct TonelessLanguageModelIndex {
    private var table: [String: [Unigram]] = [:]
    /// Longest key length in syllables (hyphen-separated), so the walker can bound spans.
    public private(set) var maxSpanLength: Int = 1

    private static let toneScalars: Set<Character> = ["ˊ", "ˇ", "ˋ", "˙"]

    public init(text: String) {
        // Aggregate best score per (tonelessKey, value).
        var best: [String: [String: Double]] = [:]
        var maxSpan = 1
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ")
            guard parts.count == 3, let score = Double(parts[2]) else { continue }
            let key = String(parts[0]).filter { !Self.toneScalars.contains($0) }
            let value = String(parts[1])
            let span = key.split(separator: "-").count
            if span > maxSpan { maxSpan = span }
            if let existing = best[key]?[value] {
                if score > existing { best[key]?[value] = score }
            } else {
                best[key, default: [:]][value] = score
            }
        }
        for (key, values) in best {
            table[key] = values
                .map { Unigram(value: $0.key, score: $0.value) }
                .sorted { $0.score != $1.score ? $0.score > $1.score : $0.value < $1.value }
        }
        maxSpanLength = maxSpan
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    /// Unigrams for a toneless key, sorted by score descending (best first). Empty if none.
    public func unigrams(forKey key: String) -> [Unigram] { table[key] ?? [] }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter TonelessLanguageModelIndexTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine/Sources/KeyKeyEngine/TonelessLanguageModelIndex.swift \
        Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/TonelessLanguageModelIndexTests.swift
git commit -m "feat(pinyin): TonelessLanguageModelIndex (separate lazy tone-stripped index)"
```

---

### Task 5: `Walker` + `WalkNode` (bounded best-path DP)

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/Walker.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/WalkerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `WalkerTests.swift`:

```swift
import XCTest
@testable import KeyKeyEngine

final class WalkerTests: XCTestCase {
    // Fixture LM: single chars for ㄋㄧ, ㄏㄠ, plus the phrase ㄋㄧ-ㄏㄠ (higher combined pref).
    private func index() -> TonelessLanguageModelIndex {
        TonelessLanguageModelIndex(text: """
        ㄋㄧ 你 -3.0
        ㄋㄧ 泥 -6.0
        ㄏㄠ 好 -3.0
        ㄏㄠ 號 -4.0
        ㄋㄧ-ㄏㄠ 你好 -5.0
        """)
    }

    func testPrefersPhraseOverTwoSingles() {
        // Two singles cost -3.0 + -3.0 = -6.0; the phrase costs -5.0 (better).
        let walker = Walker(index: index())
        let nodes = walker.walk(readings: ["ㄋㄧ", "ㄏㄠ"], rawSyllables: ["ni", "hao"],
                                userBonus: { _ in 0 })
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].chosenText, "你好")
        XCTAssertEqual(nodes[0].readingRange, 0..<2)
    }

    func testSingleReadingHasCandidatesSortedByScore() {
        let walker = Walker(index: index())
        let nodes = walker.walk(readings: ["ㄋㄧ"], rawSyllables: ["ni"], userBonus: { _ in 0 })
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].candidates, ["你", "泥"])
        XCTAssertEqual(nodes[0].chosenText, "你")
    }

    func testUserBonusReordersCandidatesButNotSegmentation() {
        let walker = Walker(index: index())
        // Big bonus for 泥 lifts it above 你 within the node.
        let nodes = walker.walk(readings: ["ㄋㄧ"], rawSyllables: ["ni"],
                                userBonus: { $0 == "泥" ? 100 : 0 })
        XCTAssertEqual(nodes[0].candidates.first, "泥")
    }

    func testUnmappedReadingFallsBackToRawText() {
        let walker = Walker(index: index())
        // ㄗㄗ has no LM entry -> raw-text node keeps the pinyin visible; path still complete.
        let nodes = walker.walk(readings: ["ㄗㄗ"], rawSyllables: ["zz"], userBonus: { _ in 0 })
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].chosenText, "zz")
    }

    func testEmptyReadings() {
        let walker = Walker(index: index())
        XCTAssertTrue(walker.walk(readings: [], rawSyllables: [], userBonus: { _ in 0 }).isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter WalkerTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'Walker' in scope`.

- [ ] **Step 3: Implement**

Create `Walker.swift`:

```swift
import Foundation

/// One node of a walk: a contiguous run of readings and the ordered candidates
/// for that run. `chosenIndex` selects which candidate is committed/shown.
public struct WalkNode: Equatable {
    public let readingRange: Range<Int>
    public let candidates: [String]
    public var chosenIndex: Int
    public init(readingRange: Range<Int>, candidates: [String], chosenIndex: Int = 0) {
        self.readingRange = readingRange
        self.candidates = candidates
        self.chosenIndex = chosenIndex
    }
    public var chosenText: String {
        guard chosenIndex >= 0, chosenIndex < candidates.count else { return candidates.first ?? "" }
        return candidates[chosenIndex]
    }
}

/// Best-path walk over a sequence of toneless zhuyin readings, using unigram
/// scores from a TonelessLanguageModelIndex. Maximizes the summed unigram
/// log-prob (longer/higher-scored phrases win). Bounded so per-keystroke cost
/// stays linear: spans never exceed `maxSpanLength`, and callers cap the reading
/// count (PinyinEngine.maxComposingSyllables).
public struct Walker {
    private let index: TonelessLanguageModelIndex
    private let maxSpan: Int
    /// Score for a raw-text fallback node — below any real log-prob, so the walk
    /// only uses it when nothing better spans that reading.
    private static let rawFallbackScore = -30.0

    public init(index: TonelessLanguageModelIndex) {
        self.index = index
        self.maxSpan = max(1, index.maxSpanLength)
    }

    public func walk(readings: [String], rawSyllables: [String],
                     userBonus: (Character) -> Double) -> [WalkNode] {
        let n = readings.count
        guard n > 0 else { return [] }
        precondition(rawSyllables.count == n, "readings and rawSyllables must align")

        // DP over prefix boundaries: best[j] = best total score covering readings[0..<j].
        var best = [Double](repeating: -.greatestFiniteMagnitude, count: n + 1)
        var back = [WalkNode?](repeating: nil, count: n + 1)
        var prev = [Int](repeating: 0, count: n + 1)
        best[0] = 0

        for j in 1...n {
            let maxL = min(maxSpan, j)
            for L in 1...maxL {
                let i = j - L
                if best[i] == -.greatestFiniteMagnitude { continue }
                let key = readings[i..<j].joined(separator: "-")
                let unis = index.unigrams(forKey: key)
                let spanScore: Double
                let node: WalkNode
                if unis.isEmpty {
                    guard L == 1 else { continue } // no phrase for a multi-reading span
                    spanScore = Self.rawFallbackScore
                    node = WalkNode(readingRange: i..<j, candidates: [rawSyllables[i]])
                } else {
                    spanScore = unis.map(\.score).max() ?? Self.rawFallbackScore
                    // Display order: LM score + user-learning bonus on the leading character.
                    let ordered = unis.sorted { a, b in
                        let sa = a.score + (a.value.first.map(userBonus) ?? 0)
                        let sb = b.score + (b.value.first.map(userBonus) ?? 0)
                        return sa != sb ? sa > sb : a.value < b.value
                    }.map(\.value)
                    node = WalkNode(readingRange: i..<j, candidates: ordered)
                }
                let total = best[i] + spanScore
                if total > best[j] {
                    best[j] = total
                    back[j] = node
                    prev[j] = i
                }
            }
        }

        // Backtrack from n to 0.
        var nodes: [WalkNode] = []
        var j = n
        while j > 0, let node = back[j] {
            nodes.append(node)
            j = prev[j]
        }
        return nodes.reversed()
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter WalkerTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Add a perf/bounds test**

Append to `WalkerTests.swift`:

```swift
extension WalkerTests {
    func testLongInputCompletesQuickly() {
        let walker = Walker(index: index())
        let readings = Array(repeating: "ㄋㄧ", count: 24)
        let raws = Array(repeating: "ni", count: 24)
        let start = Date()
        let nodes = walker.walk(readings: readings, rawSyllables: raws, userBonus: { _ in 0 })
        XCTAssertFalse(nodes.isEmpty)
        // Reconstructed reading coverage must be complete.
        XCTAssertEqual(nodes.reduce(0) { $0 + $1.readingRange.count }, 24)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.1)
    }
}
```

- [ ] **Step 6: Run + commit**

Run: `cd Packages/KeyKeyEngine && swift test --filter WalkerTests 2>&1 | tail -20` → PASS.
```bash
git add Packages/KeyKeyEngine/Sources/KeyKeyEngine/Walker.swift \
        Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/WalkerTests.swift
git commit -m "feat(pinyin): bounded best-path Walker + WalkNode"
```

---

### Task 6: `PinyinEngine` (composing buffer)

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/PinyinEngine.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/PinyinEngineTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PinyinEngineTests.swift`:

```swift
import XCTest
@testable import KeyKeyEngine

final class PinyinEngineTests: XCTestCase {
    private func makeEngine() -> PinyinEngine {
        let table = PinyinSyllableTable(text: """
        ni\tㄋㄧ
        hao\tㄏㄠ
        wo\tㄨㄛ
        """)
        let index = TonelessLanguageModelIndex(text: """
        ㄋㄧ 你 -3.0
        ㄋㄧ 泥 -6.0
        ㄏㄠ 好 -3.0
        ㄋㄧ-ㄏㄠ 你好 -5.0
        ㄨㄛ 我 -3.0
        """)
        return PinyinEngine(syllableTable: table, index: index, userRank: { _ in 0 })
    }

    func testTypingComposesBestPath() {
        let e = makeEngine()
        for c in "nihao" { _ = e.handleKey(c) }
        XCTAssertEqual(e.composingText, "你好")
    }

    func testCandidatesAtCursor() {
        let e = makeEngine()
        _ = e.handleKey("n"); _ = e.handleKey("i")
        XCTAssertEqual(e.candidates, ["你", "泥"]) // cursor on the only node
    }

    func testSelectCandidateOverridesNode() {
        let e = makeEngine()
        _ = e.handleKey("n"); _ = e.handleKey("i")
        e.selectCandidate(1)                 // pick 泥
        XCTAssertEqual(e.composingText, "泥")
    }

    func testCursorMovementAcrossNodes() {
        let e = makeEngine()
        for c in "wo" { _ = e.handleKey(c) }
        for c in "ni" { _ = e.handleKey(c) } // two nodes: 我 | 你
        XCTAssertEqual(e.composingText, "我你")
        XCTAssertEqual(e.candidates.first, "我")   // cursor starts on first node
        XCTAssertTrue(e.moveCursorRight())
        XCTAssertEqual(e.candidates, ["你", "泥"])  // cursor now on second node
        XCTAssertFalse(e.moveCursorRight())         // already at last node
        XCTAssertTrue(e.moveCursorLeft())
        XCTAssertEqual(e.candidates.first, "我")
    }

    func testBackspaceRemovesLastLetterAndRewalks() {
        let e = makeEngine()
        for c in "nihao" { _ = e.handleKey(c) }
        e.backspace()                        // drop 'o'
        XCTAssertTrue(e.composingText.hasPrefix("你"))
    }

    func testCommitReturnsFullTextAndResets() {
        let e = makeEngine()
        for c in "nihao" { _ = e.handleKey(c) }
        XCTAssertEqual(e.commit(), "你好")
        XCTAssertEqual(e.composingText, "")
        XCTAssertTrue(e.candidates.isEmpty)
    }

    func testTailKeptVisible() {
        let e = makeEngine()
        for c in "nix" { _ = e.handleKey(c) } // 'x' can't extend/segment -> tail
        XCTAssertEqual(e.composingText, "你x")
    }

    func testMaxComposingSyllablesCap() {
        let e = makeEngine()
        for _ in 0..<50 { _ = e.handleKey("n"); _ = e.handleKey("i") }
        XCTAssertLessThanOrEqual(e.syllableCountForTesting, PinyinEngine.maxComposingSyllables)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter PinyinEngineTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'PinyinEngine' in scope`.

- [ ] **Step 3: Implement**

Create `PinyinEngine.swift`:

```swift
import Foundation

/// Phrase/sentence Pinyin engine. Accumulates typed letters, segments them into
/// syllables, converts to toneless zhuyin readings, and runs the Walker to build
/// an editable list of nodes. A node cursor selects which node the candidate
/// window addresses. Unparsable trailing input is kept as a visible raw tail.
public final class PinyinEngine {
    /// Upper bound on syllables in one composition (keeps the per-keystroke walk cheap).
    public static let maxComposingSyllables = 24

    private let syllableTable: PinyinSyllableTable
    private let index: TonelessLanguageModelIndex
    private let userRank: (Character) -> Double
    private let walker: Walker
    private let segmenter: PinyinSegmenter

    private var raw: String = ""            // all typed letters (+ apostrophes)
    private var nodes: [WalkNode] = []
    private var tail: String = ""
    private var cursor: Int = 0             // index into `nodes`

    public init(syllableTable: PinyinSyllableTable,
                index: TonelessLanguageModelIndex,
                userRank: @escaping (Character) -> Double = { _ in 0 }) {
        self.syllableTable = syllableTable
        self.index = index
        self.userRank = userRank
        self.walker = Walker(index: index)
        self.segmenter = PinyinSegmenter(table: syllableTable)
    }

    // MARK: Input

    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        guard (key.isLetter && key.isASCII) || key == "'" else { return false }
        // Cap: refuse further input once at the syllable limit (swallow the key).
        let seg = segmenter.segment(raw + String(key))
        if seg.syllables.count > Self.maxComposingSyllables { return true }
        raw.append(key)
        rewalk()
        return true
    }

    public func backspace() {
        guard !raw.isEmpty else { return }
        raw.removeLast()
        rewalk()
    }

    // MARK: Cursor + candidates

    /// Candidates for the node under the cursor (empty if there is no node).
    public var candidates: [String] {
        guard cursor >= 0, cursor < nodes.count else { return [] }
        return nodes[cursor].candidates
    }

    public func selectCandidate(_ index: Int) {
        guard cursor >= 0, cursor < nodes.count else { return }
        guard index >= 0, index < nodes[cursor].candidates.count else { return }
        nodes[cursor].chosenIndex = index
    }

    @discardableResult
    public func moveCursorLeft() -> Bool {
        guard cursor > 0 else { return false }
        cursor -= 1; return true
    }

    @discardableResult
    public func moveCursorRight() -> Bool {
        guard cursor < nodes.count - 1 else { return false }
        cursor += 1; return true
    }

    // MARK: Output

    public var composingText: String {
        nodes.map(\.chosenText).joined() + tail
    }

    @discardableResult
    public func commit() -> String {
        let text = composingText
        raw = ""; nodes = []; tail = ""; cursor = 0
        return text
    }

    // MARK: Testing hooks
    public var syllableCountForTesting: Int { nodes.reduce(0) { $0 + $1.readingRange.count } }

    // MARK: Private

    private func rewalk() {
        let seg = segmenter.segment(raw)
        tail = seg.tail
        let readings = seg.syllables.compactMap { syllableTable.zhuyin(forSyllable: $0) }
        nodes = walker.walk(readings: readings, rawSyllables: seg.syllables, userBonus: userRank)
        if cursor >= nodes.count { cursor = max(0, nodes.count - 1) }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter PinyinEngineTests 2>&1 | tail -20`
Expected: PASS. (If `testBackspaceRemovesLastLetterAndRewalks` proves brittle on the exact tail, keep only the `hasPrefix("你")` assertion.)

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine/Sources/KeyKeyEngine/PinyinEngine.swift \
        Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/PinyinEngineTests.swift
git commit -m "feat(pinyin): PinyinEngine composing buffer (nodes, cursor, cap)"
```

---

### Task 7: Golden test against the real LM

**Files:**
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/RealPinyinWalkerTests.swift`

Skips when `data.txt` / `pinyin-zhuyin.txt` are absent (clean checkout), exactly like `RealCangjieTableTests`.

- [ ] **Step 1: Write the test**

Create `RealPinyinWalkerTests.swift`:

```swift
import XCTest
@testable import KeyKeyEngine

final class RealPinyinWalkerTests: XCTestCase {
    private func url(_ rel: String) -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let c = dir.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: c.path) { return c }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testKnownPhrasesResolve() throws {
        guard let dataURL = url("Resources/data.txt"),
              let mapURL = url("Resources/pinyin-zhuyin.txt") else {
            throw XCTSkip("data.txt / pinyin-zhuyin.txt not present")
        }
        let table = try PinyinSyllableTable(contentsOf: mapURL)
        let index = try TonelessLanguageModelIndex(contentsOf: dataURL)
        let engine = PinyinEngine(syllableTable: table, index: index)

        func type(_ s: String) -> String {
            _ = engine.commit()
            for c in s { _ = engine.handleKey(c) }
            let out = engine.composingText
            _ = engine.commit()
            return out
        }
        XCTAssertEqual(type("nihao"), "你好")
        XCTAssertEqual(type("womenqu"), "我們去")
    }
}
```

- [ ] **Step 2: Run**

Run: `cd Packages/KeyKeyEngine && swift test --filter RealPinyinWalkerTests 2>&1 | tail -20`
Expected: PASS if `data.txt` present (build it first with `tools/build-lm.sh`); otherwise SKIP. If a phrase resolves differently, adjust the expected string to what the real LM produces (the LM, not the test, is the oracle) and note it in the commit message.

- [ ] **Step 3: Full suite + commit**

Run: `cd Packages/KeyKeyEngine && swift test 2>&1 | tail -20`
Expected: all PASS (real tests may SKIP).
```bash
git add Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/RealPinyinWalkerTests.swift
git commit -m "test(pinyin): golden walk against real LM (skips if data absent)"
```

**✅ Phase 1 checkpoint:** headless engine complete and green. Review, then proceed to Phase 2.

---

# PHASE 2 — IMK wiring + resource contract

> Detailed at the Phase 1→2 boundary against the real Phase 1 API. The tasks, files, signatures, and commands below are fixed now; per-step code is finalized then (IMK behavior is verified interactively via a re-id'd debug build).

### Task 8: `PhraseComposingEngine` protocol + conformance

**Files:** Modify `App/InputEngine.swift`.

- [ ] Add protocol and conformance:
```swift
// Richer surface for phrase-composition engines (Pinyin). Cangjie/Simplex do NOT conform.
protocol PhraseComposingEngine: InputEngine {
    func moveCursorLeft() -> Bool
    func moveCursorRight() -> Bool
}
extension PinyinEngine: InputEngine {}          // handleKey/composingText/candidates/selectCandidate/backspace/commit
extension PinyinEngine: PhraseComposingEngine {} // moveCursorLeft/right
```
- [ ] Verify `PinyinEngine`'s public API already satisfies both (it does, from Task 6).
- [ ] Commit.

### Task 9: Reference-counted lazy Pinyin index in `SharedResources`

**Files:** Modify `App/SharedResources.swift`.

- [ ] Eagerly load the tiny `PinyinSyllableTable` in `init` (small; safe to always load), from `Bundle.main.url(forResource:"pinyin-zhuyin", withExtension:"txt")`, fail-safe to empty (`PinyinSyllableTable(text:"")`) with an `NSLog`. Expose `let pinyinSyllableTable: PinyinSyllableTable`.
- [ ] Add ref-counted state (guarded by an `NSLock`): `private var pinyinIndex: TonelessLanguageModelIndex?`, `private var pinyinRefCount = 0`, `private let pinyinLock = NSLock()`.
- [ ] Add:
```swift
/// Acquire the shared Pinyin index (built on first acquire from data.txt). Ref-counted.
func acquirePinyinIndex() -> TonelessLanguageModelIndex?
/// Release a previous acquire; drops the strong reference at count 0.
func releasePinyinIndex()
```
  - `acquire`: lock/defer-unlock; `pinyinRefCount += 1`; if `pinyinIndex == nil`, read `data.txt` (same `Bundle.main.url(forResource:"data")` path used at line 31) and build the index; on load failure roll back the count and return `nil` with an `NSLog`; else return the index.
  - `release`: lock/defer-unlock; `pinyinRefCount = max(0, pinyinRefCount - 1)`; if `0` then `pinyinIndex = nil`.
- [ ] Do **not** touch `init`'s `characterRank` derivation or the Cangjie/Simplex fields.
- [ ] Commit.

### Task 10: Register Pinyin module + controller lifecycle + key routing

**Files:** Modify `App/InputController.swift`.

- [ ] **Registry** (in `init`, after the Simplex module, ~line 51): append a Pinyin module. `makeEngine` must be cheap and **must not build the index** — build the engine against `shared.acquirePinyinIndex()`'s result, but perform the acquire in `setValue` (mode entry), not in the closure. Concretely, store the acquired index on the controller and have the Pinyin `makeEngine` read it:
```swift
InputMethodModule(modeSuffix: "Pinyin", displayName: "拼音") { [weak self] in
    let idx = self?.activePinyinIndex ?? TonelessLanguageModelIndex(text: "")
    return PinyinEngine(syllableTable: shared.pinyinSyllableTable, index: idx, userRank: userRank)
}
```
  where `private var activePinyinIndex: TonelessLanguageModelIndex?` is set in `setValue` before `makeEngine()` is called. (Finalize the exact wiring here; the invariant is **registration alone builds nothing**.)
- [ ] **Lifecycle in `setValue`** (~line 215): before building the new engine, if entering Pinyin set `activePinyinIndex = shared.acquirePinyinIndex()`; if leaving Pinyin (previous module was Pinyin) call `shared.releasePinyinIndex()` and clear `activePinyinIndex`.
- [ ] **`deinit`** (~line 67): if the current module is Pinyin, `shared.releasePinyinIndex()` (a controller can die while in Pinyin).
- [ ] **Key routing** — insert a `PhraseComposingEngine` branch **before** the existing `if !engine.candidates.isEmpty` block (~line 302):
```swift
if let phrase = engine as? PhraseComposingEngine, !engine.composingText.isEmpty {
    switch event.keyCode {
    case 123, 126: _ = phrase.moveCursorLeft();  candidatePage = 0; refresh(client); return true // Left/Up
    case 124, 125: _ = phrase.moveCursorRight(); candidatePage = 0; refresh(client); return true // Right/Down
    case 49, 36:  return commitCurrent(to: client, offerAssociations: true) // Space/Enter commit ALL
    case 51:      engine.backspace(); candidatePage = 0; refresh(client); return true            // Backspace
    default: break
    }
    if let chars = event.characters, let d = Int(chars), (1...9).contains(d) {
        let idx = candidatePage * InputController.pageSize + (d - 1)
        if idx < engine.candidates.count { engine.selectCandidate(idx) } // PIN, do not commit
        candidatePage = 0; refresh(client); return true
    }
    // fall through so letter keys reach engine.handleKey below
}
```
  Cangjie/Simplex are unaffected (they never match `as? PhraseComposingEngine`).
- [ ] Manual smoke test (Task 12) then commit.

### Task 11: Info.plist input mode + build/packaging

**Files:** Modify `App/Info.plist`, `tools/build-app.sh`.

- [ ] **Info.plist**: under `ComponentInputModeDict → tsInputModeListKey`, add
  `com.dragonapp.inputmethod.yahoo-keykey.Pinyin` (copy the Simplex entry; `TISIntendedLanguage` `zh-Hant`, `tsInputModeScriptKey` `smTradChinese`, same icon keys, display name 拼音). Append the same id to `tsVisibleInputModeOrderedArrayKey`.
- [ ] **build-app.sh**: after the Cangjie/三代 copy block (~line 133), add a copy with a fail-if-missing guard:
```bash
echo "==> Copying bundled Pinyin map (pinyin-zhuyin.txt)"
if [ ! -f "$ROOT/Resources/pinyin-zhuyin.txt" ]; then
  echo "ERROR: Resources/pinyin-zhuyin.txt missing; run tools/build-pinyin-map.py first" >&2
  exit 1
fi
cp "$ROOT/Resources/pinyin-zhuyin.txt" "$APP/Contents/Resources/pinyin-zhuyin.txt"
```
  No new `App/*.swift` files are added by this plan, so the `swiftc` source list at line 106 does **not** change. If Phase 2 introduces a new App file, add it there.
- [ ] Confirm `installer/` and the `dragon-release-ci` path pick up `Resources/pinyin-zhuyin.txt` (they run `build-app.sh`, so the copy above covers them; verify no separate allow-list excludes it).

### Task 12: Lifecycle acceptance tests + manual smoke test

- [ ] **Lifecycle asserts** (in the package where a `SharedResources`-like seam is testable, or a small dedicated harness): registry construction does **not** acquire the index; two acquires keep it alive, releasing one keeps it, releasing both drops it (assert `pinyinIndex == nil` after count 0 — object graph, not RSS); a Cangjie/Simplex-only run never retains a `TonelessLanguageModelIndex`.
- [ ] **Manual smoke test** — build a re-id'd debug bundle per the global macOS rule (bundle id `com.dragonapp.inputmethod.yahoo-keykey.debug`, name **Yahoo KeyKey Debug**; re-id **main bundle only**; deep ad-hoc re-sign **without** hardened runtime — see the `dragon-mac-ops` skill / `tools/run-debug.sh`). Install to `~/Library/Input Methods`, select 拼音, and in TextEdit verify: `nihao`→你好, candidate window + digit pick, arrow cursor movement, a `ü` syllable (`lv`), a long phrase, backspace, and space-commit. Confirm `Bundle.main.url(forResource:"pinyin-zhuyin", withExtension:"txt")` resolves in the installed bundle.

**✅ Phase 2 checkpoint:** Pinyin usable end-to-end in a debug build. Review, then Phase 3.

---

# PHASE 3 — Polish + release

### Task 13: Parity + edge-case polish

- [ ] Candidate window paging/highlight parity with Cangjie/Simplex; highlight the cursor node in the marked text (underline/segment attributes on the composing string in `refresh`).
- [ ] Ensure `AssociatedPhrases` still only fires on single-character commits (the existing `text.count == 1` guard in `commitCurrent`, line 391, already handles multi-char Pinyin commits — verify, do not change).
- [ ] Edge cases: commit with a pending tail (commit tail literally); Esc behavior; empty-composition space passes through.
- [ ] `UserFrequency`: confirm the leading-character bonus flows via `userRank` into `Walker` candidate ordering; record on commit consistent with current behavior (single-char records only, per existing code) — do not oversell as phrase learning.

### Task 14: Docs + changelog

- [ ] `CHANGELOG.md`: add the Pinyin feature under a new version heading (follow existing style).
- [ ] `README.md`: note 拼音 support (marketing-site changelog flows via the i18n pipeline — out of scope for this repo PR).
- [ ] Update the spec `Status:` to `Implemented`.
- [ ] Final full build + test: `tools/build-app.sh --build-lm` then `cd Packages/KeyKeyEngine && swift test`.

---

## Self-Review

**Spec coverage:**
- §2.1 map → Task 1. §2.2 table → Task 2. §2.3 segmenter → Task 3. §2.4 walker + bounds/raw-text node → Task 5. §2.5 separate lazy index → Task 4. §2.6 engine → Task 6. §2.7 registry/branch-order/ref-counted lifecycle → Tasks 8–10. §2.8 build/packaging → Task 11. §2.9 reused (UserFrequency honesty, 聯想 single-char) → Task 13. §4 error handling (raw-text node, no crash) → Tasks 5–6. §5 testing incl. lifecycle acceptance + `v`/`ü` + perf → Tasks 2,3,5,6,7,12. §6 phasing → whole plan. Coverage complete.

**Placeholder scan:** Phase 1 has complete code + commands. Phase 2/3 tasks are concrete (files, signatures, plist keys, script edits, commands) with the explicit note that per-step IMK code is finalized at the phase boundary — by design (interactive IMK verification), not hand-waving.

**Type consistency:** `PinyinSyllableTable(text:)`/`.zhuyin(forSyllable:)`/`.isValidSyllable`/`.maxSyllableLength`/`.syllableCount`; `PinyinSegmenter(table:).segment(_)→(syllables,tail)`; `TonelessLanguageModelIndex(text:)`/`.unigrams(forKey:)`/`.maxSpanLength`; `Walker(index:).walk(readings:rawSyllables:userBonus:)→[WalkNode]`; `WalkNode.readingRange/candidates/chosenIndex/chosenText`; `PinyinEngine(syllableTable:index:userRank:)` + `handleKey/composingText/candidates/selectCandidate/backspace/commit/moveCursorLeft/moveCursorRight/syllableCountForTesting` + `static maxComposingSyllables`. Consistent across tasks.
