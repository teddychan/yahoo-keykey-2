import XCTest
@testable import KeyKeyEngine

// ETen26 (倚天26鍵) 26-key layout. Verified against McBopomofo Mandarin.cpp
// CreateETen26Layout() and syllableFromKeySequence(). ETen26 has NO Hsu fixups;
// its consonant/vowel/tone disambiguation comes purely from the per-key
// component vectors plus the look-ahead JQX / E / ZCSR rules.
final class Eten26LayoutTests: XCTestCase {
    private let layout = Eten26Layout()

    private func resolve(_ key: Character, given: Syllable = Syllable()) -> Syllable? {
        if case .phoneme(let s) = layout.resolve(key: key, given: given) { return s }
        return nil
    }
    private func resolveRaw(_ key: Character, given: Syllable = Syllable()) -> Resolution? {
        layout.resolve(key: key, given: given)
    }
    private func syl(c: Character? = nil, m: Character? = nil,
                     v: Character? = nil, t: Character? = nil) -> Syllable {
        var s = Syllable(); s.consonant = c; s.medial = m; s.vowel = v; s.tone = t
        return s
    }

    // MARK: Unambiguous (ASSIGNKEY1) keys

    func testDirectKeys() {
        XCTAssertEqual(resolve("b"), syl(c: "ㄅ"))   // b -> B
        XCTAssertEqual(resolve("s"), syl(c: "ㄙ"))   // s -> S
        XCTAssertEqual(resolve("y"), syl(c: "ㄔ"))   // y -> CH (single)
        XCTAssertEqual(resolve("e"), syl(m: "ㄧ"))   // e -> I (medial)
        XCTAssertEqual(resolve("x"), syl(m: "ㄨ"))   // x -> U
        XCTAssertEqual(resolve("u"), syl(m: "ㄩ"))   // u -> UE
        XCTAssertEqual(resolve("a"), syl(v: "ㄚ"))   // a -> A
        XCTAssertEqual(resolve("o"), syl(v: "ㄛ"))   // o -> O
        XCTAssertEqual(resolve("r"), syl(v: "ㄜ"))   // r -> ER
        XCTAssertEqual(resolve("i"), syl(v: "ㄞ"))   // i -> AI
        XCTAssertEqual(resolve("z"), syl(v: "ㄠ"))   // z -> AO
    }

    // MARK: Ambiguous keys alone — "single char in buffer" rule resolves to the
    // SECOND (vowel) component when head is a bare consonant.

    func testAmbiguousAloneYieldsVowelReading() {
        XCTAssertEqual(resolve("p"), syl(v: "ㄡ"))   // p=[P,OU] -> ㄡ
        XCTAssertEqual(resolve("m"), syl(v: "ㄢ"))   // m=[M,AN] -> ㄢ
        XCTAssertEqual(resolve("t"), syl(v: "ㄤ"))   // t=[T,ANG] -> ㄤ
        XCTAssertEqual(resolve("n"), syl(v: "ㄣ"))   // n=[N,EN] -> ㄣ
        XCTAssertEqual(resolve("l"), syl(v: "ㄥ"))   // l=[L,ENG] -> ㄥ
        XCTAssertEqual(resolve("h"), syl(v: "ㄦ"))   // h=[H,ERR] -> ㄦ
        // q/w heads are ZCSR consonants, so the single-char rule keeps the HEAD
        // (consonant), not the vowel. Ground truth: q->ㄗ, w->ㄘ.
        XCTAssertEqual(resolve("q"), syl(c: "ㄗ"))   // q=[Z,EI] head Z is ZCSR -> ㄗ
        XCTAssertEqual(resolve("w"), syl(c: "ㄘ"))   // w=[C,E] head C is ZCSR -> ㄘ
    }

    func testAmbiguousConsonantOnlyKeysAlone() {
        // v=[G,Q]: head G no vowel, follow Q no tone, head not ZCSR -> follow
        // has vowel? Q no -> ending(==follow) Q? -> ground truth: ㄍ (head wins
        // via the general path is N/A here; verified value is ㄍ).
        XCTAssertEqual(resolve("v"), syl(c: "ㄍ"))   // v=[G,Q] -> ㄍ
        XCTAssertEqual(resolve("g"), syl(c: "ㄓ"))   // g=[ZH,J] head ZCSR -> ㄓ
        XCTAssertEqual(resolve("c"), syl(c: "ㄕ"))   // c=[SH,X] head ZCSR -> ㄕ
    }

    // MARK: Tone keys — only become tones once the syllable has content.

    func testFIsConsonantAloneTone2WithContent() {
        // f=[F,Tone2]. Alone -> ㄈ. With content (ㄅㄚ) -> ˊ.
        XCTAssertEqual(resolve("f"), syl(c: "ㄈ"))
        XCTAssertEqual(resolveRaw("f", given: syl(c: "ㄅ", v: "ㄚ")), .tone("ˊ"))
    }

    func testDIsConsonantAloneTone5WithContent() {
        // d=[D,Tone5]. Alone -> ㄉ. With content -> ˙.
        XCTAssertEqual(resolve("d"), syl(c: "ㄉ"))
        XCTAssertEqual(resolveRaw("d", given: syl(c: "ㄅ", v: "ㄚ")), .tone("˙"))
    }

    func testKIsConsonantAloneTone4WithContent() {
        // k=[K,Tone4]. Alone -> ㄎ. With content -> ˋ.
        XCTAssertEqual(resolve("k"), syl(c: "ㄎ"))
        XCTAssertEqual(resolveRaw("k", given: syl(c: "ㄅ", v: "ㄚ")), .tone("ˋ"))
    }

    func testJIsConsonantAloneTone3WithContent() {
        // j=[R,Tone3]. Alone -> ㄖ. With content -> ˇ.
        XCTAssertEqual(resolve("j"), syl(c: "ㄖ"))
        XCTAssertEqual(resolveRaw("j", given: syl(c: "ㄅ", v: "ㄚ")), .tone("ˇ"))
    }

    // MARK: JQX class rule — g/v/c flip to their J/Q/X reading before medial ㄧ.

    func testGIsZhAloneButJiBeforeI() {
        // g=[ZH,J]. Alone -> ㄓ. Followed by medial e(ㄧ): re-parse "ge" -> the
        // JQX rule + aheadSeqHasIorUE picks J -> ㄐㄧ. Ground truth: ㄐㄧ.
        XCTAssertEqual(resolve("g"), syl(c: "ㄓ"))
        XCTAssertEqual(resolve("e", given: syl(c: "ㄓ")), syl(c: "ㄐ", m: "ㄧ"))
    }

    func testVIsGAloneButQiBeforeI() {
        // v=[G,Q]. Alone -> ㄍ. Before medial ㄧ -> ㄑㄧ. Ground truth: ㄑㄧ.
        XCTAssertEqual(resolve("v"), syl(c: "ㄍ"))
        XCTAssertEqual(resolve("e", given: syl(c: "ㄍ")), syl(c: "ㄑ", m: "ㄧ"))
    }

    func testCIsShAloneButXiBeforeI() {
        // c=[SH,X]. Alone -> ㄕ. Before medial ㄧ -> ㄒㄧ. Ground truth: ㄒㄧ.
        XCTAssertEqual(resolve("c"), syl(c: "ㄕ"))
        XCTAssertEqual(resolve("e", given: syl(c: "ㄕ")), syl(c: "ㄒ", m: "ㄧ"))
    }

    // MARK: E rule — w=[C,E]: C alone, ㄝ when an I/UE medial precedes.

    func testWIsCAloneButEAfterMedialI() {
        XCTAssertEqual(resolve("w"), syl(c: "ㄘ"))   // w alone -> ㄘ (consonant C)
        // After medial ㄧ present (ㄅㄧ): w -> follow E (ㄝ). Ground truth bew: ㄅㄧㄝ.
        XCTAssertEqual(resolve("w", given: syl(c: "ㄅ", m: "ㄧ")),
                       syl(c: "ㄅ", m: "ㄧ", v: "ㄝ"))
    }

    // MARK: After-consonant disambiguation (vowel reading wins)

    func testPAfterConsonantIsOuVowel() {
        // p=[P,OU]; after a consonant, follow OU wins. ㄅ + p -> ㄅㄡ.
        XCTAssertEqual(resolve("p", given: syl(c: "ㄅ")), syl(c: "ㄅ", v: "ㄡ"))
    }

    func testHAfterConsonantIsErrVowel() {
        // h=[H,ERR]; after a consonant -> ㄦ. Ground truth bh: ㄅㄦ.
        XCTAssertEqual(resolve("h", given: syl(c: "ㄅ")), syl(c: "ㄅ", v: "ㄦ"))
    }

    // MARK: Integration through ReadingBuffer (tone completes)

    func testReadingBufferCompletesOnEten26Tone() {
        var b = ReadingBuffer(layout: Eten26Layout())
        XCTAssertEqual(b.receive("b"), .updated("ㄅ"))     // ㄅ
        XCTAssertEqual(b.receive("a"), .updated("ㄅㄚ"))   // + ㄚ
        XCTAssertEqual(b.receive("f"), .completed("ㄅㄚˊ")) // f -> tone2 completes
        XCTAssertTrue(b.isEmpty)
    }

    // Multi-key words, ground-truthed against the McBopomofo C++ engine.
    func testEten26Words() {
        func compose(_ keys: String) -> String {
            var b = ReadingBuffer(layout: Eten26Layout())
            var last = ""
            for k in keys { if case .updated(let s) = b.receive(k) { last = s } }
            return last
        }
        XCTAssertEqual(compose("vea"), "ㄑㄧㄚ")   // v->ㄑ(before ㄧ), ㄧ, ㄚ
        XCTAssertEqual(compose("gea"), "ㄐㄧㄚ")   // g->ㄐ(before ㄧ), ㄧ, ㄚ
        XCTAssertEqual(compose("weq"), "ㄘㄧㄟ")   // w->ㄘ, e->ㄧ, q->ㄟ
    }

    func testReadingBufferGeToJiThenVowel() {
        var b = ReadingBuffer(layout: Eten26Layout())
        XCTAssertEqual(b.receive("g"), .updated("ㄓ"))     // g alone -> ㄓ
        XCTAssertEqual(b.receive("e"), .updated("ㄐㄧ"))   // JQX rule -> ㄐㄧ
        XCTAssertEqual(b.receive("a"), .updated("ㄐㄧㄚ")) // + ㄚ
    }
}
