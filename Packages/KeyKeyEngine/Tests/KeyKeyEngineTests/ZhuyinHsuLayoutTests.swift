import XCTest
@testable import KeyKeyEngine

// 許氏 (Hsu): the 26-letter layout whose keys change meaning with their neighbours. Each case is a
// real syllable typed the way a 許氏 typist types it, key by key through the engine, so what is
// pinned is the reading the person sees — including the half-typed states along the way.
final class ZhuyinHsuLayoutTests: XCTestCase {
    private func engine() -> ZhuyinEngine {
        ZhuyinEngine(table: ZhuyinTable(text: "ㄋㄧˇ\t你\nㄏㄠˇ\t好\nㄕˋ\t是"), layout: .hsu)
    }

    private func typed(_ keys: String) -> String {
        let e = engine()
        for key in keys { _ = e.handleKey(key) }
        return e.composingText
    }

    func testEverydaySyllablesSpellTheirReading() {
        let cases: [(keys: String, reading: String)] = [
            ("nef", "ㄋㄧˇ"),    // 你
            ("hwf", "ㄏㄠˇ"),    // 好
            ("cj", "ㄕˋ"),       // 是 — c is ㄕ here, not ㄒ
            ("xhf", "ㄨㄛˇ"),    // 我 — h is ㄛ after a medial
            ("jxl", "ㄓㄨㄥ"),   // 中 — j is ㄓ, l is ㄥ
            ("gxhd", "ㄍㄨㄛˊ"), // 國
            ("dgs", "ㄉㄜ˙"),    // 的
            ("jey", "ㄐㄧㄚ"),   // 加 — j is ㄐ because ㄧ follows
            ("jemj", "ㄐㄧㄢˋ"), // 見 — m is ㄢ after a medial; the last j is the tone
            ("lj", "ㄦˋ"),       // 二 — a bare ㄥ becomes ㄦ
            ("uej", "ㄩㄝˋ"),    // 月 — e is ㄝ after ㄩ
            ("cekf", "ㄒㄧㄤˇ"), // 想
            ("cued", "ㄒㄩㄝˊ"), // 學
            ("fn", "ㄈㄣ"),      // 分
            ("xad", "ㄨㄟˊ"),    // 為 — a is ㄟ after a medial
            ("zij", "ㄗㄞˋ"),    // 在
            ("cxh", "ㄕㄨㄛ"),   // 說
            ("jgj", "ㄓㄜˋ"),    // 這
        ]
        for (keys, reading) in cases {
            XCTAssertEqual(typed(keys), reading, "\(keys) should spell \(reading)")
        }
    }

    func testALoneKeyReadsAsTheSyllableItStandsForOnItsOwn() {
        XCTAssertEqual(typed("m"), "ㄢ")   // 安
        XCTAssertEqual(typed("g"), "ㄜ")
        XCTAssertEqual(typed("l"), "ㄦ")
        XCTAssertEqual(typed("e"), "ㄧ")
        XCTAssertEqual(typed("v"), "ㄔ")
        XCTAssertEqual(typed("a"), "ㄘ")
        XCTAssertEqual(typed("b"), "ㄅ")
    }

    func testTheCharacterComesOutOnceTheToneLands() {
        let e = engine()
        for key in "nef" { _ = e.handleKey(key) }
        XCTAssertEqual(e.candidates, ["你"])
        XCTAssertEqual(e.commit(), "你")
    }

    func testSpaceIsTheFirstTone() {
        let e = engine()
        for key in "m" { _ = e.handleKey(key) }
        XCTAssertTrue(e.applyFirstTone())
        XCTAssertEqual(e.composingText, "ㄢ")
        XCTAssertNotNil(e.candidateListKey)
    }

    func testAFinishedSyllableAlwaysYieldsToTheNextCharacter() {
        let e = engine()
        for key in "nef" { _ = e.handleKey(key) }
        // `d`, `f`, `j`, `s` are tone keys AND ㄉ ㄈ ㄐ ㄙ: after a finished syllable they begin
        // the next character rather than correcting the tone.
        for key in "dfjsbm" {
            XCTAssertTrue(e.keyStartsNewComposition(key), "\(key)")
        }
    }

    func testBackspaceTakesBackTheLastKey() {
        let e = engine()
        for key in "nef" { _ = e.handleKey(key) }
        e.backspace()
        XCTAssertEqual(e.composingText, "ㄋㄧ")
    }

    func testBackspaceOnASpaceToneRemovesTheTone() {
        let e = engine()
        for key in "nxhy" { _ = e.handleKey(key) }
        XCTAssertTrue(e.applyFirstTone())
        e.backspace()
        XCTAssertEqual(e.composingText, typed("nxhy"))
    }

    func testOnlyTheTwentyFiveLettersAreClaimed() {
        let e = engine()
        for key in "abcdefghijklmnoprstuvwxyz" { XCTAssertTrue(e.mapsKey(key), "\(key)") }
        for key in "q,./;-'[]1234567890" { XCTAssertFalse(e.mapsKey(key), "\(key)") }
    }

    func testAToneWithNothingToSitOnIsNeverASyllable() {
        let e = engine()
        // Every tone key is also a consonant, so a tone-only result can only come from a repeat.
        for key in "ff" { _ = e.handleKey(key) }
        XCTAssertEqual(e.composingText, "ㄈ")
    }
}
