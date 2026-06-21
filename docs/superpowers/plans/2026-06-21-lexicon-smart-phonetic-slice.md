# Lexicon + Smart Phonetic Vertical Slice — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Swift macOS input method that lets a user type Traditional Chinese in Smart Phonetic mode with the Standard Bopomofo layout — composing buffer, candidate window, selection, and commit-to-any-app — backed by the open McBopomofo language model.

**Architecture:** A pure-Swift SwiftPM package `KeyKeyEngine` (no UI, fully unit-tested) holds the syllable composer, the Standard-layout key map, the language-model loader, and a unigram Viterbi walker. A thin Xcode `.app` target hosts an `IMKServer` + `IMKInputController` subclass that drives the engine and renders marked text + a minimal candidate `NSPanel`. The engine knows nothing about IMK; the app knows nothing about walk internals.

**Tech Stack:** Swift 5.9+, SwiftPM (engine + tests), Xcode `.app` target, InputMethodKit, AppKit. macOS arm64 + x86_64. LM data from McBopomofo (MIT; libtabe-derived — attribution required).

**Decisions inherited from the spec** (`docs/superpowers/specs/2026-06-21-keykey-lexicon-smart-phonetic-slice-design.md`):
- `KeyKey.db` is encrypted (spike NO-GO) → LM source is the **open McBopomofo** model.
- McBopomofo's engine is **unigram-only** (confirmed in research); we build unigram-only. This supersedes the spec's "unigram + bigram" wording for the adopted engine.
- Out of scope: other input methods/layouts, filters, aux modules, Preferences, Phrase Editor, the full window family, update/sync, installer packaging.

---

## File Structure

```
Packages/KeyKeyEngine/
  Package.swift
  Sources/KeyKeyEngine/
    Syllable.swift            # packed Bopomofo syllable -> BPMF Unicode string
    StandardLayout.swift      # QWERTY key char -> phoneme component (Dachen)
    ReadingBuffer.swift       # assemble keystrokes into one syllable; emit completed reading
    LanguageModel.swift       # parse sorted McBopomofo LM text; unigram lookup by reading key
    Walker.swift              # ReadingGrid + Node + Unigram + Viterbi best-path & candidates
    SmartPhoneticEngine.swift # orchestrates buffer + grid + walk; public input API
  Tests/KeyKeyEngineTests/
    SyllableTests.swift
    StandardLayoutTests.swift
    ReadingBufferTests.swift
    LanguageModelTests.swift
    WalkerTests.swift
    SmartPhoneticEngineTests.swift
App/
  main.swift                  # IMKServer bootstrap
  InputController.swift        # IMKInputController subclass; drives engine; marked text/commit
  CandidateWindow.swift        # borderless NSPanel candidate list
  Info.plist                   # IMK keys
tools/
  build-lm.sh                  # build McBopomofo data.txt; copy into App resources
Resources/
  data.txt                     # bundled LM (produced by build-lm.sh; git-ignored)
docs/THIRD-PARTY-NOTICES.md    # McBopomofo MIT + libtabe attribution
```

Each engine file has one responsibility and is independently testable. The app files are integration glue, verified by build + manual smoke test (IMK cannot be unit-tested without a live session).

---

## Conventions

- Commit author is the repo default (`teddychan <teddychan@gmail.com>` — already configured).
- Run engine tests from the package dir: `cd Packages/KeyKeyEngine`.
- BPMF Unicode reference used throughout: consonants ㄅ(U+3105)…ㄙ(U+3119); medials ㄧㄨㄩ (U+3127–U+3129); finals ㄚ…ㄦ (U+311A–U+3126); tones ˊ(U+02CA) ˇ(U+02C7) ˋ(U+02CB) ˙(U+02D9); tone-1 = no mark. Reading keys join syllables with `-`.

---

### Task 1: Scaffold the engine package

**Files:**
- Create: `Packages/KeyKeyEngine/Package.swift`
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/KeyKeyEngine.swift`
- Create: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/SmokeTests.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyKeyEngine",
    platforms: [.macOS(.v12)],
    products: [.library(name: "KeyKeyEngine", targets: ["KeyKeyEngine"])],
    targets: [
        .target(name: "KeyKeyEngine"),
        .testTarget(name: "KeyKeyEngineTests", dependencies: ["KeyKeyEngine"]),
    ]
)
```

- [ ] **Step 2: Write a placeholder source so the target compiles**

`Sources/KeyKeyEngine/KeyKeyEngine.swift`:

```swift
// KeyKeyEngine: pure-Swift Bopomofo Smart Phonetic engine. No UI, no IMK.
public enum KeyKeyEngine {
    public static let version = "0.1.0"
}
```

- [ ] **Step 3: Write a smoke test**

`Tests/KeyKeyEngineTests/SmokeTests.swift`:

```swift
import XCTest
@testable import KeyKeyEngine

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(KeyKeyEngine.version, "0.1.0")
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd Packages/KeyKeyEngine && swift test`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine
git commit -m "feat(engine): scaffold KeyKeyEngine SwiftPM package"
```

---

### Task 2: Bopomofo syllable → BPMF string

A `Syllable` holds at most one phoneme per class and renders the canonical BPMF string in order: consonant, medial, vowel, tone. Tone-1 renders no mark.

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/Syllable.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/SyllableTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import KeyKeyEngine

final class SyllableTests: XCTestCase {
    func testEmptySyllable() {
        XCTAssertTrue(Syllable().isEmpty)
        XCTAssertEqual(Syllable().bpmf, "")
    }

    func testComposeOrderedString() {
        var s = Syllable()
        s.medial = "ㄧ"; s.consonant = "ㄅ"; s.tone = "ˊ"; s.vowel = "ㄠ"
        // canonical order regardless of insertion order: consonant+medial+vowel+tone
        XCTAssertEqual(s.bpmf, "ㄅㄧㄠˊ")
    }

    func testToneOneHasNoMark() {
        var s = Syllable()
        s.consonant = "ㄇ"; s.vowel = "ㄚ"; s.tone = nil
        XCTAssertEqual(s.bpmf, "ㄇㄚ")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter SyllableTests`
Expected: FAIL — `cannot find 'Syllable' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Syllable.swift`:

```swift
// One Bopomofo syllable: at most one phoneme per class.
// Render order is fixed: consonant, medial, vowel, tone.
public struct Syllable: Equatable {
    public var consonant: Character?   // ㄅ..ㄙ
    public var medial: Character?      // ㄧ ㄨ ㄩ
    public var vowel: Character?       // ㄚ..ㄦ
    public var tone: Character?        // ˊ ˇ ˋ ˙  ; nil == tone 1 (no mark)

    public init() {}

    public var isEmpty: Bool {
        consonant == nil && medial == nil && vowel == nil && tone == nil
    }

    public var bpmf: String {
        var out = ""
        if let consonant { out.append(consonant) }
        if let medial { out.append(medial) }
        if let vowel { out.append(vowel) }
        if let tone { out.append(tone) }
        return out
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter SyllableTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine
git commit -m "feat(engine): Syllable renders canonical BPMF string"
```

---

### Task 3: Standard (Dachen) layout key map

Maps a typed ASCII character to a phoneme component and its class. Table verbatim from McBopomofo `CreateStandardLayout()`.

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/StandardLayout.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/StandardLayoutTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import KeyKeyEngine

final class StandardLayoutTests: XCTestCase {
    func testConsonantKeys() {
        XCTAssertEqual(StandardLayout.component(for: "1"), .consonant("ㄅ"))
        XCTAssertEqual(StandardLayout.component(for: "z"), .consonant("ㄈ"))
    }
    func testMedialAndVowel() {
        XCTAssertEqual(StandardLayout.component(for: "u"), .medial("ㄧ"))
        XCTAssertEqual(StandardLayout.component(for: "8"), .vowel("ㄚ"))
    }
    func testToneKeys() {
        XCTAssertEqual(StandardLayout.component(for: " "), .tone(nil))   // space = tone 1
        XCTAssertEqual(StandardLayout.component(for: "6"), .tone("ˊ"))
        XCTAssertEqual(StandardLayout.component(for: "3"), .tone("ˇ"))
        XCTAssertEqual(StandardLayout.component(for: "4"), .tone("ˋ"))
        XCTAssertEqual(StandardLayout.component(for: "7"), .tone("˙"))
    }
    func testUnmappedKey() {
        XCTAssertNil(StandardLayout.component(for: "`"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter StandardLayoutTests`
Expected: FAIL — `cannot find 'StandardLayout' in scope`.

- [ ] **Step 3: Write minimal implementation**

`StandardLayout.swift`:

```swift
// Standard (大千 / Dachen) Bopomofo layout. ASCII key -> phoneme component.
// Source of truth: McBopomofo Mandarin.cpp CreateStandardLayout().
public enum Component: Equatable {
    case consonant(Character)
    case medial(Character)
    case vowel(Character)
    case tone(Character?)   // nil == tone 1 (no mark)
}

public enum StandardLayout {
    private static let consonants: [Character: Character] = [
        "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ",
        "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
        "e": "ㄍ", "d": "ㄎ", "c": "ㄏ",
        "r": "ㄐ", "f": "ㄑ", "v": "ㄒ",
        "5": "ㄓ", "t": "ㄔ", "g": "ㄕ", "b": "ㄖ",
        "y": "ㄗ", "h": "ㄘ", "n": "ㄙ",
    ]
    private static let medials: [Character: Character] = [
        "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
    ]
    private static let vowels: [Character: Character] = [
        "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ",
        "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
        "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ",
        "-": "ㄦ",
    ]
    private static let tones: [Character: Character?] = [
        " ": nil, "6": "ˊ", "3": "ˇ", "4": "ˋ", "7": "˙",
    ]

    public static func component(for key: Character) -> Component? {
        if let c = consonants[key] { return .consonant(c) }
        if let m = medials[key] { return .medial(m) }
        if let v = vowels[key] { return .vowel(v) }
        if let t = tones[key] { return .tone(t) }   // value may itself be nil (tone 1)
        return nil
    }
}
```

> Note: `tones[" "]` stores `Optional(nil)`. `if let t = tones[key]` unwraps the *outer* optional, so `t` is `Character?` and `.tone(nil)` is produced for space. Confirmed by `testToneKeys`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter StandardLayoutTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine
git commit -m "feat(engine): Standard (Dachen) layout key map"
```

---

### Task 4: Reading buffer (keystrokes → completed reading)

Feeds layout components into a `Syllable`, overwriting the slot of each class. A tone key (including space = tone 1) **completes** the syllable: the buffer returns the finished reading string and clears. Backspace removes the most-recently-set component.

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/ReadingBuffer.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/ReadingBufferTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import KeyKeyEngine

final class ReadingBufferTests: XCTestCase {
    func testBuildAndCompleteOnTone() {
        var b = ReadingBuffer()
        // type "ㄇㄠ" then space (tone 1): keys a, l, space
        XCTAssertEqual(b.receive("a"), .updated("ㄇ"))
        XCTAssertEqual(b.receive("l"), .updated("ㄇㄠ"))
        XCTAssertEqual(b.receive(" "), .completed("ㄇㄠ"))
        XCTAssertTrue(b.isEmpty)
    }

    func testToneMarkCompletes() {
        var b = ReadingBuffer()
        _ = b.receive("a")          // ㄇ
        _ = b.receive("l")          // ㄇㄠ
        XCTAssertEqual(b.receive("4"), .completed("ㄇㄠˋ"))
    }

    func testOverwriteSameClass() {
        var b = ReadingBuffer()
        _ = b.receive("1")          // ㄅ
        XCTAssertEqual(b.receive("q"), .updated("ㄆ"))   // consonant replaced
    }

    func testBackspaceRemovesLastComponent() {
        var b = ReadingBuffer()
        _ = b.receive("a")          // ㄇ
        _ = b.receive("l")          // ㄇㄠ
        XCTAssertEqual(b.backspace(), .updated("ㄇ"))
        XCTAssertEqual(b.backspace(), .updated(""))
        XCTAssertEqual(b.backspace(), .empty)
    }

    func testUnmappedKeyIgnored() {
        var b = ReadingBuffer()
        _ = b.receive("a")
        XCTAssertEqual(b.receive("`"), .unhandled)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter ReadingBufferTests`
Expected: FAIL — `cannot find 'ReadingBuffer' in scope`.

- [ ] **Step 3: Write minimal implementation**

`ReadingBuffer.swift`:

```swift
// Assembles layout components into one Syllable. A tone completes the syllable.
public struct ReadingBuffer {
    public enum Result: Equatable {
        case updated(String)     // syllable changed, not yet complete (BPMF so far)
        case completed(String)   // tone received; finished reading; buffer cleared
        case empty               // nothing to do (e.g. backspace on empty)
        case unhandled           // key not part of the layout
    }

    private var syllable = Syllable()
    // order in which classes were set, to support backspace
    private var order: [Class] = []
    private enum Class { case consonant, medial, vowel, tone }

    public init() {}

    public var isEmpty: Bool { syllable.isEmpty }

    public mutating func receive(_ key: Character) -> Result {
        guard let component = StandardLayout.component(for: key) else { return .unhandled }
        switch component {
        case .consonant(let c): set(.consonant) { syllable.consonant = c }
        case .medial(let m):    set(.medial) { syllable.medial = m }
        case .vowel(let v):     set(.vowel) { syllable.vowel = v }
        case .tone(let t):
            // tone completes only if there is something to commit
            guard !syllable.isEmpty else { return .empty }
            syllable.tone = t
            let reading = syllable.bpmf
            syllable = Syllable(); order = []
            return .completed(reading)
        }
        return .updated(syllable.bpmf)
    }

    public mutating func backspace() -> Result {
        guard let last = order.popLast() else { return .empty }
        switch last {
        case .consonant: syllable.consonant = nil
        case .medial:    syllable.medial = nil
        case .vowel:     syllable.vowel = nil
        case .tone:      syllable.tone = nil
        }
        return .updated(syllable.bpmf)
    }

    private mutating func set(_ cls: Class, _ apply: () -> Void) {
        apply()
        order.removeAll { $0 == cls }
        order.append(cls)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter ReadingBufferTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine
git commit -m "feat(engine): ReadingBuffer assembles syllables, completes on tone"
```

---

### Task 5: Language model loader

Parses the McBopomofo sorted LM text format: a header line `# format org.openvanilla.mcbopomofo.sorted`, then lines `<readingKey> <phrase> <score>` (space-separated, sorted by key). Builds an in-memory `[key: [Unigram]]`, unigrams kept in file order (already score-descending within a key).

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/LanguageModel.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/LanguageModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import KeyKeyEngine

final class LanguageModelTests: XCTestCase {
    static let fixture = """
    # format org.openvanilla.mcbopomofo.sorted
    ㄅㄚ 八 -3.27631260
    ㄅㄚ 吧 -3.59800309
    ㄇㄠ 貓 -4.10000000
    ㄇㄠ-ㄇㄧ 貓咪 -5.20000000
    """

    func testLookupReturnsUnigramsInOrder() {
        let lm = LanguageModel(text: Self.fixture)
        let u = lm.unigrams(forKey: "ㄅㄚ")
        XCTAssertEqual(u.map(\.value), ["八", "吧"])
        XCTAssertEqual(u.first?.score ?? 0, -3.27631260, accuracy: 1e-6)
    }

    func testMultiSyllableKey() {
        let lm = LanguageModel(text: Self.fixture)
        XCTAssertEqual(lm.unigrams(forKey: "ㄇㄠ-ㄇㄧ").map(\.value), ["貓咪"])
    }

    func testHeaderAndBlanksIgnored() {
        let lm = LanguageModel(text: Self.fixture)
        XCTAssertTrue(lm.unigrams(forKey: "# format org.openvanilla.mcbopomofo.sorted").isEmpty)
    }

    func testMissingKey() {
        let lm = LanguageModel(text: Self.fixture)
        XCTAssertTrue(lm.unigrams(forKey: "ㄓㄨ").isEmpty)
        XCTAssertFalse(lm.hasKey("ㄓㄨ"))
        XCTAssertTrue(lm.hasKey("ㄅㄚ"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter LanguageModelTests`
Expected: FAIL — `cannot find 'LanguageModel' in scope`.

- [ ] **Step 3: Write minimal implementation**

`LanguageModel.swift`:

```swift
import Foundation

public struct Unigram: Equatable {
    public let value: String
    public let score: Double
    public init(value: String, score: Double) { self.value = value; self.score = score }
}

// Loads the McBopomofo "sorted" plain-text LM. Format per line: "<key> <phrase> <score>".
public struct LanguageModel {
    private var table: [String: [Unigram]] = [:]

    public init(text: String) {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ")
            guard parts.count == 3, let score = Double(parts[2]) else { continue }
            let key = String(parts[0])
            table[key, default: []].append(Unigram(value: String(parts[1]), score: score))
        }
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public func unigrams(forKey key: String) -> [Unigram] { table[key] ?? [] }
    public func hasKey(_ key: String) -> Bool { table[key] != nil }
}
```

> Note: file order already gives score-descending unigrams per key (the McBopomofo compiler sorts that way), so no re-sort is needed. If a future data source isn't pre-sorted, sort here — not now (YAGNI).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter LanguageModelTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine
git commit -m "feat(engine): LanguageModel parses McBopomofo sorted LM"
```

---

### Task 6: Reading grid + Viterbi walker

Builds a grid of nodes over a reading sequence and finds the best path (max sum of unigram log-probs) plus per-position candidates. Single-syllable readings with no LM entry get a fallback node whose value is the reading itself at a very low score, so the walk is always total.

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/Walker.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/WalkerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import KeyKeyEngine

final class WalkerTests: XCTestCase {
    // 今天 should beat 今+天 because the 2-syllable unigram scores higher than the sum.
    static let lm = LanguageModel(text: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄐㄧㄣ 今 -4.0
    ㄐㄧㄣ 斤 -4.5
    ㄊㄧㄢ 天 -4.0
    ㄊㄧㄢ 田 -4.6
    ㄐㄧㄣ-ㄊㄧㄢ 今天 -3.2
    """)

    func testBestPathPrefersPhrase() {
        let grid = ReadingGrid(readings: ["ㄐㄧㄣ", "ㄊㄧㄢ"], languageModel: Self.lm)
        XCTAssertEqual(grid.walk().joined(), "今天")
    }

    func testCandidatesAtPositionLongestFirst() {
        let grid = ReadingGrid(readings: ["ㄐㄧㄣ", "ㄊㄧㄢ"], languageModel: Self.lm)
        // position 0 overlaps the 2-syllable node (今天) and the 1-syllable node (今/斤)
        XCTAssertEqual(grid.candidates(at: 0), ["今天", "今", "斤"])
    }

    func testFallbackForUnknownReading() {
        let grid = ReadingGrid(readings: ["ㄓㄜ"], languageModel: Self.lm)  // not in LM
        XCTAssertEqual(grid.walk().joined(), "ㄓㄜ")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter WalkerTests`
Expected: FAIL — `cannot find 'ReadingGrid' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Walker.swift`:

```swift
// Minimal Gramambular-style grid + Viterbi walk over unigram log-probs.
public final class ReadingGrid {
    public struct Node {
        public let readingKey: String
        public let spanningLength: Int
        public var unigrams: [Unigram]
        public var overrideIndex: Int?
        public var current: Unigram { unigrams[overrideIndex ?? 0] }
    }

    private let readings: [String]
    private var nodesByStart: [[Node]]   // nodesByStart[i] = nodes beginning at position i
    private static let maxSpan = 6
    private static let fallbackScore = -99.0

    public init(readings: [String], languageModel lm: LanguageModel) {
        self.readings = readings
        self.nodesByStart = Array(repeating: [], count: readings.count)
        for i in 0..<readings.count {
            let maxLen = min(Self.maxSpan, readings.count - i)
            for len in 1...maxLen {
                let key = readings[i..<(i + len)].joined(separator: "-")
                let unigrams = lm.unigrams(forKey: key)
                if !unigrams.isEmpty {
                    nodesByStart[i].append(Node(readingKey: key, spanningLength: len,
                                                unigrams: unigrams, overrideIndex: nil))
                }
            }
            // guarantee a single-syllable node so the walk is total
            if !nodesByStart[i].contains(where: { $0.spanningLength == 1 }) {
                let r = readings[i]
                nodesByStart[i].insert(
                    Node(readingKey: r, spanningLength: 1,
                         unigrams: [Unigram(value: r, score: Self.fallbackScore)],
                         overrideIndex: nil),
                    at: 0)
            }
        }
    }

    // Viterbi over the DAG; returns the chosen nodes' current values.
    public func walk() -> [String] {
        let n = readings.count
        if n == 0 { return [] }
        var best = Array(repeating: -Double.infinity, count: n + 1)
        var fromIndex = Array(repeating: -1, count: n + 1)
        var fromNode = Array(repeating: -1, count: n + 1)
        best[0] = 0
        for i in 0..<n where best[i] > -.infinity {
            for (ni, node) in nodesByStart[i].enumerated() {
                let j = i + node.spanningLength
                let score = best[i] + node.current.score
                if score > best[j] { best[j] = score; fromIndex[j] = i; fromNode[j] = ni }
            }
        }
        var values: [String] = []
        var j = n
        while j > 0 {
            let i = fromIndex[j]
            values.append(nodesByStart[i][fromNode[j]].current.value)
            j = i
        }
        return values.reversed()
    }

    // Candidates overlapping a reading position, longer spans first, then file order.
    public func candidates(at position: Int) -> [String] {
        var spanned: [(span: Int, values: [String])] = []
        for start in 0...position {
            for node in nodesByStart[start]
                where position < start + node.spanningLength {
                spanned.append((node.spanningLength, node.unigrams.map(\.value)))
            }
        }
        spanned.sort { $0.span > $1.span }   // longest phrases first
        return spanned.flatMap(\.values)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter WalkerTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyKeyEngine
git commit -m "feat(engine): reading grid + unigram Viterbi walk and candidates"
```

---

### Task 7: SmartPhoneticEngine (public input API)

Orchestrates buffer + grid. Public surface the IMK controller will call: feed a key, read composing text + candidates, select a candidate, backspace, and commit.

**Files:**
- Create: `Packages/KeyKeyEngine/Sources/KeyKeyEngine/SmartPhoneticEngine.swift`
- Test: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/SmartPhoneticEngineTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import KeyKeyEngine

final class SmartPhoneticEngineTests: XCTestCase {
    static let lm = LanguageModel(text: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄇㄠ 貓 -4.0
    ㄇㄠ 毛 -4.2
    """)

    private func make() -> SmartPhoneticEngine { SmartPhoneticEngine(languageModel: Self.lm) }

    func testTypeOneSyllableShowsComposingAndCandidates() {
        let e = make()
        XCTAssertTrue(e.handleKey("a"))   // ㄇ
        XCTAssertTrue(e.handleKey("l"))   // ㄇㄠ
        XCTAssertTrue(e.handleKey(" "))   // tone 1 completes reading ㄇㄠ
        XCTAssertEqual(e.composingText, "貓")
        XCTAssertEqual(e.candidates, ["貓", "毛"])
    }

    func testSelectCandidateOverrides() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "毛")
    }

    func testCommitReturnsTextAndClears() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")
        XCTAssertEqual(e.commit(), "貓")
        XCTAssertEqual(e.composingText, "")
        XCTAssertTrue(e.candidates.isEmpty)
    }

    func testBackspaceRemovesReading() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("l"); _ = e.handleKey(" ")  // one reading
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testUnmappedKeyNotConsumed() {
        let e = make()
        XCTAssertFalse(e.handleKey("`"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/KeyKeyEngine && swift test --filter SmartPhoneticEngineTests`
Expected: FAIL — `cannot find 'SmartPhoneticEngine' in scope`.

- [ ] **Step 3: Write minimal implementation**

`SmartPhoneticEngine.swift`:

```swift
// Orchestrates the reading buffer and the grid walk. The IMK controller talks only to this.
public final class SmartPhoneticEngine {
    private let lm: LanguageModel
    private var buffer = ReadingBuffer()
    private var readings: [String] = []
    private var overrides: [Int: Int] = [:]   // reading index -> chosen candidate index

    public init(languageModel: LanguageModel) { self.lm = languageModel }

    /// Returns true if the key was consumed by the engine.
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        switch buffer.receive(key) {
        case .completed(let reading):
            readings.append(reading)
            return true
        case .updated, .empty:
            return true
        case .unhandled:
            return false
        }
    }

    public func backspace() {
        // if mid-syllable, edit the syllable; otherwise drop the last completed reading
        if case .empty = buffer.backspace(), !readings.isEmpty {
            readings.removeLast()
            overrides.removeValue(forKey: readings.count)
        }
    }

    public func selectCandidate(_ index: Int) {
        guard !readings.isEmpty else { return }
        overrides[readings.count - 1] = index
    }

    public var composingText: String {
        guard !readings.isEmpty else { return "" }
        // honour single-reading overrides; otherwise take the walked best path
        let walked = ReadingGrid(readings: readings, languageModel: lm).walk()
        if overrides.isEmpty { return walked.joined() }
        var out = walked
        for (i, choice) in overrides where i < readings.count {
            let cands = ReadingGrid(readings: [readings[i]], languageModel: lm).candidates(at: 0)
            if choice < cands.count, i < out.count { out[i] = cands[choice] }
        }
        return out.joined()
    }

    public var candidates: [String] {
        guard !readings.isEmpty else { return [] }
        let grid = ReadingGrid(readings: readings, languageModel: lm)
        return grid.candidates(at: readings.count - 1)
    }

    @discardableResult
    public func commit() -> String {
        let text = composingText
        readings = []; overrides = [:]; buffer = ReadingBuffer()
        return text
    }
}
```

> The override mapping is intentionally simple (per-reading single-syllable choice) — enough for the slice's "pick a candidate then keep typing" flow. Multi-syllable phrase override is deferred to sub-project 2.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/KeyKeyEngine && swift test --filter SmartPhoneticEngineTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Run the full engine suite + commit**

Run: `cd Packages/KeyKeyEngine && swift test`
Expected: PASS (all tasks' tests).

```bash
git add Packages/KeyKeyEngine
git commit -m "feat(engine): SmartPhoneticEngine public input API"
```

---

### Task 8: Build & bundle the real McBopomofo LM

Produce `Resources/data.txt` from McBopomofo's data tooling, add attribution, and add a structural validation test that runs against the real file when present.

**Files:**
- Create: `tools/build-lm.sh`
- Create: `docs/THIRD-PARTY-NOTICES.md`
- Create: `Packages/KeyKeyEngine/Tests/KeyKeyEngineTests/RealLMValidationTests.swift`
- Modify: `.gitignore` (add `Resources/data.txt`)

- [ ] **Step 1: Write `tools/build-lm.sh`**

```bash
#!/bin/bash
# Build the McBopomofo language model (data.txt) and copy it to Resources/.
# Requires: git, python3, make. Produces ./Resources/data.txt.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.lm-build"
mkdir -p "$WORK" "$ROOT/Resources"
if [ ! -d "$WORK/McBopomofo" ]; then
  git clone --depth 1 https://github.com/openvanilla/McBopomofo "$WORK/McBopomofo"
fi
cd "$WORK/McBopomofo/Source/Data"
make            # runs main_compiler.py -> data.txt
cp data.txt "$ROOT/Resources/data.txt"
echo "Wrote $ROOT/Resources/data.txt ($(wc -l < "$ROOT/Resources/data.txt") lines)"
```

- [ ] **Step 2: Make it executable and run it**

Run:
```bash
chmod +x tools/build-lm.sh && ./tools/build-lm.sh
```
Expected: prints `Wrote .../Resources/data.txt (<N> lines)` with N in the hundreds of thousands. The first line of the file is `# format org.openvanilla.mcbopomofo.sorted`.

> If `make` fails for lack of libtabe inputs, consult `Source/Data/AGENTS.md` in the clone; the committed source `.txt` files plus `make` are sufficient. Do not hand-edit data.txt.

- [ ] **Step 3: Write the attribution file**

`docs/THIRD-PARTY-NOTICES.md`:

```markdown
# Third-Party Notices

## McBopomofo (language model + algorithm reference)
MIT License. Copyright (c) 2011-2026 Mengjuei Hsieh, Lukhnos Liu, et al.
https://github.com/openvanilla/McBopomofo

The bundled `Resources/data.txt` is built from McBopomofo's data sources.

### libtabe / TaBE
McBopomofo's phrase data (`BPMFMappings.txt`) is derived from libtabe's `tsi.src`
(BSD-style license; TaBE project, Pai-Hsiang Hsiao et al.). This attribution is
preserved per that license.
```

- [ ] **Step 4: Add the validation test**

`RealLMValidationTests.swift`:

```swift
import XCTest
@testable import KeyKeyEngine

// Runs only when Resources/data.txt exists (built by tools/build-lm.sh).
final class RealLMValidationTests: XCTestCase {
    private func dataURL() -> URL? {
        // walk up from this file to repo root, then Resources/data.txt
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Resources/data.txt")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testRealLMLoadsAndComposesCommonWord() throws {
        guard let url = dataURL() else {
            throw XCTSkip("Resources/data.txt not built; run tools/build-lm.sh")
        }
        let lm = try LanguageModel(contentsOf: url)
        // 今天 (jin-tian) is a high-frequency word; expect it present and on the best path.
        XCTAssertTrue(lm.hasKey("ㄐㄧㄣ-ㄊㄧㄢ"))
        let grid = ReadingGrid(readings: ["ㄐㄧㄣ", "ㄊㄧㄢ"], languageModel: lm)
        XCTAssertEqual(grid.walk().joined(), "今天")
    }

    func testHeaderPresent() throws {
        guard let url = dataURL() else { throw XCTSkip("data.txt not built") }
        let first = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n").first.map(String.init) ?? ""
        XCTAssertEqual(first, "# format org.openvanilla.mcbopomofo.sorted")
    }
}
```

- [ ] **Step 5: Ignore the generated data + run tests + commit**

Run:
```bash
printf '\nResources/data.txt\n.lm-build/\n' >> .gitignore
cd Packages/KeyKeyEngine && swift test
```
Expected: PASS, including the two real-LM tests (not skipped) now that data.txt exists.

```bash
git add tools/build-lm.sh docs/THIRD-PARTY-NOTICES.md .gitignore Packages/KeyKeyEngine
git commit -m "feat(data): build+bundle McBopomofo LM with attribution and validation"
```

---

### Task 9: IMK app — server, controller, candidate window

The Xcode `.app` target that hosts the input method. This layer is verified by build + manual smoke test (IMK needs a live session; no XCTest). Create the Xcode project in the IDE (File ▸ New ▸ Project ▸ macOS App, product name `YahooKeyKey`), then replace the generated files with those below and add the `KeyKeyEngine` package as a local dependency (File ▸ Add Package Dependencies ▸ Add Local ▸ `Packages/KeyKeyEngine`). Set the app's Info.plist to the file below, and ensure `Resources/data.txt` is added to the app target's "Copy Bundle Resources" build phase.

**Files:**
- Create: `App/main.swift`
- Create: `App/InputController.swift`
- Create: `App/CandidateWindow.swift`
- Create/replace: `App/Info.plist`

- [ ] **Step 1: Write `App/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIdentifier</key><string>com.github.teddychan.inputmethod.YahooKeyKey</string>
    <key>CFBundleName</key><string>YahooKeyKey</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>InputMethodConnectionName</key><string>com.github.teddychan.inputmethod.YahooKeyKey_Connection</string>
    <key>InputMethodServerControllerClass</key><string>$(PRODUCT_MODULE_NAME).InputController</string>
    <key>InputMethodServerDelegateClass</key><string>$(PRODUCT_MODULE_NAME).InputController</string>
    <key>tsInputMethodCharacterRepertoireKey</key><array><string>Hant</string></array>
    <key>TISInputSourceID</key><string>com.github.teddychan.inputmethod.YahooKeyKey</string>
    <key>TISIntendedLanguage</key><string>zh-Hant</string>
    <key>ComponentInputModeDict</key>
    <dict>
        <key>tsInputModeListKey</key>
        <dict>
            <key>com.github.teddychan.inputmethod.YahooKeyKey.Bopomofo</key>
            <dict>
                <key>TISIntendedLanguage</key><string>zh-Hant</string>
                <key>tsInputModeCharacterRepertoireKey</key><array><string>Hant</string></array>
                <key>tsInputModeDefaultStateKey</key><true/>
                <key>tsInputModeIsVisibleKey</key><true/>
                <key>tsInputModeScriptKey</key><string>smTradChinese</string>
                <key>tsInputModePrimaryInScriptKey</key><true/>
            </dict>
        </dict>
        <key>tsVisibleInputModeOrderedArrayKey</key>
        <array><string>com.github.teddychan.inputmethod.YahooKeyKey.Bopomofo</string></array>
    </dict>
</dict>
</plist>
```

> The bundle identifier **must contain `inputmethod`** or macOS won't treat the app as an IME.

- [ ] **Step 2: Write `App/main.swift`**

```swift
import Cocoa
import InputMethodKit

// Retain the server for process lifetime.
var server: IMKServer?

guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      let bundleID = Bundle.main.bundleIdentifier else {
    NSLog("YahooKeyKey: missing Info.plist keys"); exit(EXIT_FAILURE)
}
server = IMKServer(name: connectionName, bundleIdentifier: bundleID)
if server == nil { NSLog("YahooKeyKey: failed to create IMKServer"); exit(EXIT_FAILURE) }
NSApplication.shared.run()
```

- [ ] **Step 3: Write `App/InputController.swift`**

```swift
import Cocoa
import InputMethodKit
import KeyKeyEngine

@objc(InputController)
final class InputController: IMKInputController {
    private let engine: SmartPhoneticEngine
    private let candidateWindow = CandidateWindow()

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        // Load the bundled LM once; fail safe to an empty model (no candidates) if missing.
        let lm: LanguageModel
        if let url = Bundle.main.url(forResource: "data", withExtension: "txt"),
           let loaded = try? LanguageModel(contentsOf: url) {
            lm = loaded
        } else {
            NSLog("YahooKeyKey: data.txt missing; running with empty LM")
            lm = LanguageModel(text: "# format org.openvanilla.mcbopomofo.sorted")
        }
        engine = SmartPhoneticEngine(languageModel: lm)
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }

        // Enter commits; Esc/Backspace edit; Space + mapped keys feed the engine.
        switch event.keyCode {
        case 36: // Return
            guard !engine.composingText.isEmpty else { return false }
            return commitCurrent(to: client)
        case 51: // Delete/Backspace
            guard !engine.composingText.isEmpty else { return false }
            engine.backspace(); refresh(client); return true
        case 53: // Escape
            guard !engine.composingText.isEmpty else { return false }
            _ = engine.commit(); refresh(client); return true
        default: break
        }

        // candidate selection via number keys 1...9 while candidates are visible
        if let chars = event.characters, let digit = Int(chars), (1...9).contains(digit),
           !engine.candidates.isEmpty {
            engine.selectCandidate(digit - 1)
            return commitCurrent(to: client)
        }

        guard let ch = event.characters?.first else { return false }
        let consumed = engine.handleKey(ch)
        if consumed { refresh(client) }
        return consumed
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        _ = commitCurrent(to: client)
    }

    @discardableResult
    private func commitCurrent(to client: IMKTextInput) -> Bool {
        let text = engine.commit()
        if !text.isEmpty {
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        candidateWindow.hide()
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        return true
    }

    private func refresh(_ client: IMKTextInput) {
        let composing = engine.composingText
        client.setMarkedText(composing,
                             selectionRange: NSRange(location: composing.utf16.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        let cands = engine.candidates
        if cands.isEmpty { candidateWindow.hide() }
        else {
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            candidateWindow.show(cands, near: rect.origin)
        }
    }
}
```

- [ ] **Step 4: Write `App/CandidateWindow.swift`**

```swift
import Cocoa

// Minimal borderless candidate list. Numbered 1..9; display only (selection is by number key).
final class CandidateWindow {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        label.font = .systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
        ])
        panel.contentView = content
    }

    func show(_ candidates: [String], near point: NSPoint) {
        let shown = candidates.prefix(9).enumerated()
            .map { "\($0.offset + 1).\($0.element)" }
            .joined(separator: "  ")
        label.stringValue = shown
        panel.setContentSize(label.intrinsicContentSize)
        panel.setFrameTopLeftPoint(NSPoint(x: point.x, y: point.y - 4))
        panel.orderFront(nil)
    }

    func hide() { panel.orderOut(nil) }
}
```

- [ ] **Step 5: Build, install, and smoke-test**

Run (adjust scheme/derived-data path as Xcode reports):
```bash
xcodebuild -scheme YahooKeyKey -configuration Debug build
APP="$(find ~/Library/Developer/Xcode/DerivedData -name 'YahooKeyKey.app' -path '*Debug*' | head -1)"
cp -R "$APP" ~/Library/Input\ Methods/
killall YahooKeyKey 2>/dev/null || true
```
Then: System Settings ▸ Keyboard ▸ Input Sources ▸ Edit… ▸ "+" ▸ Traditional Chinese ▸ **YahooKeyKey** ▸ Add. Switch to it (Ctrl-Space), open TextEdit, and verify:
- Typing `a l space` shows `貓`-class candidates; number `1` commits `貓`.
- Typing a multi-syllable sequence (e.g. `ㄐㄧㄣ` then `ㄊㄧㄢ`: `r u p 3`? use the layout map) walks to a phrase and commits on Return.
- Backspace edits the buffer; Esc clears it; the candidate panel appears/disappears.

Expected: characters commit into TextEdit; the host app never crashes. (Re-run the copy + `killall` loop to iterate.)

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(app): IMK server, input controller, candidate window (Smart Phonetic slice)"
```

---

## Self-Review

**Spec coverage** (against `2026-06-21-keykey-...-slice-design.md`):
- §2.1 lexicon-tools → Task 8 (build-lm.sh + validation + attribution). ✓
- §2.2 engine (composer, layout, LanguageModel, walk) → Tasks 2–7. ✓
- §2.3 IMK shell (controller, TIS reg via Info.plist, marked text/commit) → Task 9. ✓
- §2.4 minimal candidate window → Task 9 (`CandidateWindow`). ✓
- §3 data flow (key → handle → engine → marked text/candidates → commit) → Task 9 `handle`/`refresh`/`commitCurrent`. ✓
- §5 error handling (fail safe on LM load failure, never crash host, no passthrough mode) → Task 9 `init!` empty-LM fallback. ✓
- §6 testing (fixture + real-LM golden + headless engine drive) → engine tests Tasks 2–7 drive the engine exactly as the controller does; real-LM golden Task 8. ✓
- Out-of-scope items are absent from all tasks. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code. Task 9 is manual-verified by design (IMK), with exact files and commands.

**Type consistency:** `Component` enum (Task 3) is consumed by `ReadingBuffer` (Task 4). `Unigram` (Task 5) is used by `ReadingGrid`/`Walker` (Task 6) and `SmartPhoneticEngine` (Task 7). Engine public API names (`handleKey`, `composingText`, `candidates`, `selectCandidate`, `backspace`, `commit`) match between Task 7 and the controller in Task 9. `LanguageModel(text:)` / `LanguageModel(contentsOf:)` used consistently in Tasks 5, 8, 9.

**Known simplification (flagged, not a gap):** candidate selection in the slice is single-reading (last syllable) only; multi-syllable phrase override and cursor movement are deferred to sub-project 2 per the spec's scope.
