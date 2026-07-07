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
