import XCTest
@testable import KeyKeyEngine

// The slot rules of one 注音 syllable: what replaces what, what order it reads in, and what
// counts as finished.
final class ZhuyinSyllableTests: XCTestCase {
    private func syllable(_ symbols: String) -> ZhuyinSyllable {
        var s = ZhuyinSyllable()
        for symbol in symbols { _ = s.insert(symbol) }
        return s
    }

    func testPartsReadInCanonicalOrderHoweverTheyWereTyped() {
        XCTAssertEqual(syllable("ㄋㄧㄠˇ").reading, "ㄋㄧㄠˇ")
        // Typed final-first: 注音 is slots, not a list of keystrokes, so it still reads ㄋㄧㄠ.
        XCTAssertEqual(syllable("ㄠㄧㄋˇ").reading, "ㄋㄧㄠˇ")
    }

    func testASymbolReplacesItsOwnSlot() {
        // Typing ㄆ after ㄅ corrects the initial rather than appending to it.
        XCTAssertEqual(syllable("ㄅㄆㄚ").reading, "ㄆㄚ")
        XCTAssertEqual(syllable("ㄧㄨ").reading, "ㄨ")
        XCTAssertEqual(syllable("ㄕㄤㄥ").reading, "ㄕㄥ")
    }

    func testTheLastToneTypedWins() {
        XCTAssertEqual(syllable("ㄕˊˋ").reading, "ㄕˋ")
    }

    func testFirstToneIsUnmarked() {
        var s = syllable("ㄕ")
        XCTAssertTrue(s.applyFirstTone())
        XCTAssertEqual(s.reading, "ㄕ")
        XCTAssertTrue(s.isComplete, "a first-tone syllable is finished, mark or no mark")
    }

    func testNeutralToneIsASuffixLikeTheOthers() {
        // The convention the bundled table and McBopomofo's model share: ㄉㄜ˙, not ˙ㄉㄜ.
        XCTAssertEqual(syllable("ㄉㄜ˙").reading, "ㄉㄜ˙")
    }

    func testEmptyAndIncompleteStates() {
        var s = ZhuyinSyllable()
        XCTAssertTrue(s.isEmpty)
        XCTAssertFalse(s.hasSymbol)
        XCTAssertFalse(s.isComplete)
        XCTAssertNil(s.reading)
        XCTAssertEqual(s.displayText, "")
        _ = s.insert("ㄅ")
        XCTAssertFalse(s.isEmpty)
        XCTAssertFalse(s.isComplete, "no tone yet, so no candidate list to address")
        XCTAssertEqual(s.displayText, "ㄅ")
    }

    func testAToneWithNothingToToneIsRejected() {
        var s = ZhuyinSyllable()
        XCTAssertFalse(s.insert("ˇ"), "a stray tone key must fall through to the app")
        XCTAssertFalse(s.applyFirstTone())
        XCTAssertTrue(s.isEmpty)
    }

    func testNonZhuyinIsRejected() {
        var s = ZhuyinSyllable()
        XCTAssertFalse(s.insert("a"))
        XCTAssertFalse(s.insert("日"))
        XCTAssertFalse(s.insert("*"))
        XCTAssertTrue(s.isEmpty)
    }

    func testBackspaceRemovesTheLastPartWrittenNotTheLastKeyTyped() {
        var s = syllable("ㄋㄧㄠˇ")
        XCTAssertTrue(s.removeLast()); XCTAssertEqual(s.reading, "ㄋㄧㄠ")
        XCTAssertTrue(s.removeLast()); XCTAssertEqual(s.reading, "ㄋㄧ")
        XCTAssertTrue(s.removeLast()); XCTAssertEqual(s.reading, "ㄋ")
        XCTAssertTrue(s.removeLast()); XCTAssertNil(s.reading)
        XCTAssertFalse(s.removeLast(), "nothing left to remove")
    }

    func testClearResetsEverything() {
        var s = syllable("ㄋㄧˇ")
        s.clear()
        XCTAssertTrue(s.isEmpty)
    }

    func testToneMarks() {
        XCTAssertEqual(ZhuyinSyllable.Tone.first.mark, "")
        XCTAssertEqual(ZhuyinSyllable.Tone.second.mark, "ˊ")
        XCTAssertEqual(ZhuyinSyllable.Tone.third.mark, "ˇ")
        XCTAssertEqual(ZhuyinSyllable.Tone.fourth.mark, "ˋ")
        XCTAssertEqual(ZhuyinSyllable.Tone.neutral.mark, "˙")
        XCTAssertEqual(ZhuyinSyllable.Tone.tone(forMark: "ˋ"), .fourth)
        XCTAssertNil(ZhuyinSyllable.Tone.tone(forMark: "ㄅ"))
        XCTAssertNil(ZhuyinSyllable.Tone.tone(forMark: "ˉ"), "the first tone has no key of its own")
    }
}
