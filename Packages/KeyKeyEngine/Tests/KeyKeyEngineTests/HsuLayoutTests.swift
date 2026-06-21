import XCTest
@testable import KeyKeyEngine

// Hsu (許氏) 26-key layout. Verified against McBopomofo Mandarin.cpp:
// CreateHsuLayout() (key->component vectors) and BopomofoKeyboardLayout::
// syllableFromKeySequence() (the state-dependent disambiguation + Hsu fixups).
//
// Helper: feed a key string into a fresh ReadingBuffer using HsuLayout and
// return the resulting composed bpmf (the buffer is re-created per call).
final class HsuLayoutTests: XCTestCase {
    private let layout = HsuLayout()

    // Resolve a single key to its new syllable (phoneme case). Tone cases are
    // asserted separately via `resolveRaw`.
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

    func testDirectConsonants() {
        XCTAssertEqual(resolve("b"), syl(c: "ㄅ"))   // ASSIGNKEY1 b -> B
        XCTAssertEqual(resolve("p"), syl(c: "ㄆ"))   // p -> P
        XCTAssertEqual(resolve("t"), syl(c: "ㄊ"))   // t -> T
        XCTAssertEqual(resolve("r"), syl(c: "ㄖ"))   // r -> R
        XCTAssertEqual(resolve("z"), syl(c: "ㄗ"))   // z -> Z
    }

    func testDirectMediomVowels() {
        XCTAssertEqual(resolve("x"), syl(m: "ㄨ"))   // x -> U (medial)
        XCTAssertEqual(resolve("u"), syl(m: "ㄩ"))   // u -> UE (medial)
        XCTAssertEqual(resolve("y"), syl(v: "ㄚ"))   // y -> A
        XCTAssertEqual(resolve("i"), syl(v: "ㄞ"))   // i -> AI
        XCTAssertEqual(resolve("w"), syl(v: "ㄠ"))   // w -> AO
        XCTAssertEqual(resolve("o"), syl(v: "ㄡ"))   // o -> OU
    }

    // MARK: Ambiguous keys — "single char in buffer" rule (line 280-294)
    // When the key is the ONLY thing typed, head (the consonant/first comp) wins
    // if it has a vowel, the follow has a tone, or head is ZCSR. Otherwise follow.

    func testAmbiguousConsonantAloneYieldsConsonant() {
        // m = [M, AN]; head M is a consonant (no vowel, follow AN has no tone,
        // M not ZCSR) -> "the nasty issue": head has no vowel, follow no tone,
        // head not ZCSR -> follow has vowel -> follow wins? No: head M.
        // Rule: head.hasVowel()? no. follow.hasToneMarker()? no.
        // head.belongsToZCSRClass()? no -> else: follow.hasVowel()(AN yes) -> follow.
        // So bare "m" -> AN (ㄢ). (matches McBopomofo: lone m is the vowel.)
        XCTAssertEqual(resolve("m"), syl(v: "ㄢ"))
    }

    func testHToneAloneYieldsConsonant() {
        // h = [H, O]; head H consonant no vowel; follow O has vowel, no tone;
        // head not ZCSR -> follow wins -> O (ㄛ). Lone "h" -> ㄛ.
        XCTAssertEqual(resolve("h"), syl(v: "ㄛ"))
    }

    // MARK: Ambiguous keys after a consonant — general rule (line 296-308)
    // After a consonant is present, the key's vowel reading is taken because
    // its consonant reading overlaps the existing consonant mask.

    func testManYieldsConsonantThenVowel() {
        // type b (ㄅ) then m: m=[M,AN]. syllable has consonant mask set, head M
        // is consonant -> mask overlaps -> not head. follow AN is a vowel ->
        // follow wins -> ㄅ + ㄢ.
        let afterB = resolve("m", given: syl(c: "ㄅ"))
        XCTAssertEqual(afterB, syl(c: "ㄅ", v: "ㄢ"))
    }

    func testNAfterConsonantYieldsEnVowel() {
        // d? no, use g: type g(ㄍ) then n: n=[N, EN]; consonant present, head N
        // overlaps consonant -> follow EN wins -> ㄍ + ㄣ.
        XCTAssertEqual(resolve("n", given: syl(c: "ㄍ")), syl(c: "ㄍ", v: "ㄣ"))
    }

    func testKAfterConsonantYieldsAngVowel() {
        // k = [K, ANG]; after a consonant, follow ANG wins.
        XCTAssertEqual(resolve("k", given: syl(c: "ㄉ")), syl(c: "ㄉ", v: "ㄤ"))
    }

    // MARK: Tone keys that are tones only when content exists

    func testFIsConsonantWhenEmptyToneWhenContent() {
        // f = [F, Tone3]. Empty buffer: single-char rule. head F consonant,
        // no vowel; follow Tone3 hasToneMarker -> head wins -> ㄈ.
        XCTAssertEqual(resolve("f"), syl(c: "ㄈ"))
        // With content (ㄇㄚ): f resolves to Tone3 (ˇ). general rule: head F
        // consonant overlaps? syllable has consonant ㄇ -> head overlaps ->
        // else branch -> follow Tone3 wins.
        XCTAssertEqual(resolveRaw("f", given: syl(c: "ㄇ", v: "ㄚ")), .tone("ˇ"))
    }

    func testDIsConsonantWhenEmptyTone2WhenContent() {
        // d = [D, Tone2]. Empty -> ㄉ. With content -> ˊ.
        XCTAssertEqual(resolve("d"), syl(c: "ㄉ"))
        XCTAssertEqual(resolveRaw("d", given: syl(c: "ㄇ", v: "ㄚ")), .tone("ˊ"))
    }

    func testSIsConsonantWhenEmptyTone5WhenContent() {
        // s = [S, Tone5]. Empty -> ㄙ. With content -> ˙.
        XCTAssertEqual(resolve("s"), syl(c: "ㄙ"))
        XCTAssertEqual(resolveRaw("s", given: syl(c: "ㄎ", v: "ㄜ")), .tone("˙"))
    }

    func testJIsConsonantWhenEmptyTone4WhenFullSyllable() {
        // j = [J, ZH, Tone4]. Empty: head J is JQX; single-char rule: head no
        // vowel, follow ZH no tone, head not ZCSR -> follow has vowel? ZH no ->
        // ending Tone4 -> but ending.hasToneMarker -> actually:
        // head.hasVowel()? no; follow.hasToneMarker()(ZH)? no;
        // head.belongsToZCSRClass()(J)? no -> else: follow.hasVowel()(ZH)? no;
        // ending.hasToneMarker()(Tone4)? yes -> follow (ZH). Lone j -> ㄓ.
        XCTAssertEqual(resolve("j"), syl(c: "ㄓ"))
        // With a full syllable (ㄓㄨㄛ): j -> Tone4 (ˋ).
        XCTAssertEqual(resolveRaw("j", given: syl(c: "ㄓ", m: "ㄨ", v: "ㄛ")), .tone("ˋ"))
    }

    // MARK: JQX class rule (line 258-268) — j/v/c gain I/UE medial context

    func testVIsQiWhenFollowedByIElseCh() {
        // v = [Q, CH]. Q belongs to JQX, CH does not. Empty buffer, append v:
        // JQX rule, syllable empty -> aheadHasIorUE? (nothing ahead) no -> follow
        // CH. Lone v -> ㄔ.
        XCTAssertEqual(resolve("v"), syl(c: "ㄔ"))
    }

    func testCIsShWhenAlone() {
        // c = [X, SH]; X is JQX, SH not. Empty: follow SH wins -> ㄕ.
        XCTAssertEqual(resolve("c"), syl(c: "ㄕ"))
    }

    // MARK: E rule (line 245-256) — e = [I, E]

    func testEIsIWhenAloneEIsEAfterConsonant() {
        // e = [I, E]. head I is medial(no vowel), follow E is vowel ㄝ.
        // "before/after I-or-UE": this key IS the I/UE source. Empty append e:
        // E-rule: head.vowel? I has NO vowel component (it's a medial) so the E
        // rule branch checks head.vowelComponent()==E (no) and
        // follow.vowelComponent()==E (yes) -> beforeSeqHasIorUE? (no I/UE before)
        // -> head -> I (ㄧ). Lone e -> ㄧ.
        XCTAssertEqual(resolve("e"), syl(m: "ㄧ"))
        // After a consonant with no I/UE before: still head (medial I).
        XCTAssertEqual(resolve("e", given: syl(c: "ㄋ")), syl(c: "ㄋ", m: "ㄧ"))
    }

    func testEIsEWhenMedialIAlreadyPresent() {
        // If medial ㄧ (I) already present, beforeSeqHasIorUE true -> follow E (ㄝ).
        // e.g. ㄋ + ㄧ then e -> ㄋㄧㄝ.
        XCTAssertEqual(resolve("e", given: syl(c: "ㄋ", m: "ㄧ")),
                       syl(c: "ㄋ", m: "ㄧ", v: "ㄝ"))
    }

    // MARK: Hsu fixups (line 311-322)

    func testGiBecomesJi() {
        // Fixup: consonant G + medial I -> consonant J. Type g(ㄍ) then e(ㄧ):
        // -> ㄐㄧ (J + I), NOT ㄍㄧ.
        XCTAssertEqual(resolve("e", given: syl(c: "ㄍ")), syl(c: "ㄐ", m: "ㄧ"))
    }

    func testGueBecomesJue() {
        // Fixup: consonant G + medial UE -> J. g(ㄍ) then u(ㄩ) -> ㄐㄩ.
        XCTAssertEqual(resolve("u", given: syl(c: "ㄍ")), syl(c: "ㄐ", m: "ㄩ"))
    }

    func testBareEngBecomesErr() {
        // Fixup: vowel ENG (ㄥ) with no consonant and no medial -> add ERR (ㄦ).
        // l = [L, ENG, ERR]. Lone l: single-char rule picks... then fixup.
        // Result should be ㄦ (ERR) per the "left out L to ERR" fixup.
        XCTAssertEqual(resolve("l"), syl(v: "ㄦ"))
    }

    func testLBecomesConsonantWhenVowelTypedAfter() {
        // l is L/ENG/ERR. Typed FIRST then a vowel, l resolves to consonant ㄌ.
        // Ground truth: Hsu [ly]: 'ㄦ' 'ㄌㄚ'  (l alone is ㄦ; appending y(ㄚ)
        // re-parses "ly" -> ㄌ + ㄚ). Verified via ReadingBuffer.
        var b = ReadingBuffer(layout: HsuLayout())
        XCTAssertEqual(b.receive("l"), .updated("ㄦ"))
        XCTAssertEqual(b.receive("y"), .updated("ㄌㄚ"))
    }

    // MARK: Integration through ReadingBuffer (tone completes)

    func testReadingBufferCompletesOnHsuTone() {
        var b = ReadingBuffer(layout: HsuLayout())
        XCTAssertEqual(b.receive("c"), .updated("ㄕ"))     // lone c -> ㄕ
        XCTAssertEqual(b.receive("y"), .updated("ㄕㄚ"))   // + ㄚ
        // s now resolves to tone5 (˙) because syllable has content -> completes.
        XCTAssertEqual(b.receive("s"), .completed("ㄕㄚ˙"))
        XCTAssertTrue(b.isEmpty)
    }

    // Multi-key words, ground-truthed against the McBopomofo C++ engine.
    func testHsuWords() {
        func compose(_ keys: String) -> String {
            var b = ReadingBuffer(layout: HsuLayout())
            var last = ""
            for k in keys { if case .updated(let s) = b.receive(k) { last = s } }
            return last
        }
        XCTAssertEqual(compose("cye"), "ㄒㄧㄚ")   // c->ㄒ(JQX before ㄧ), ㄧ, ㄚ
        XCTAssertEqual(compose("jxe"), "ㄐㄧ")     // j ZH/J, x ㄨ?-> ㄐㄧ
        XCTAssertEqual(compose("le"), "ㄌㄧ")      // l->ㄌ then ㄧ
        XCTAssertEqual(compose("lu"), "ㄌㄩ")      // l->ㄌ then ㄩ
        XCTAssertEqual(compose("ne"), "ㄋㄧ")      // n->ㄋ then ㄧ
    }

    func testReadingBufferGiToJiThenTone() {
        // Ground truth: Hsu [ged]: 'ㄜ' 'ㄐㄧ' 'ㄐㄧˊ'. Lone g is ㄜ; appending e
        // re-parses "ge" -> ㄍㄧ -> Hsu fixup -> ㄐㄧ; d adds tone2.
        var b = ReadingBuffer(layout: HsuLayout())
        XCTAssertEqual(b.receive("g"), .updated("ㄜ"))     // g alone -> ㄜ
        XCTAssertEqual(b.receive("e"), .updated("ㄐㄧ"))   // fixup ㄍㄧ -> ㄐㄧ
        XCTAssertEqual(b.receive("d"), .completed("ㄐㄧˊ")) // d -> tone2
    }
}
