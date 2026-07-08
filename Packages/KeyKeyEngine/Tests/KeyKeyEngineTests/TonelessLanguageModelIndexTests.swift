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

    func testReadingForCharacterReturnsBestTonelessReading() {
        let idx = TonelessLanguageModelIndex(text: sample)
        XCTAssertEqual(idx.reading(forCharacter: "好"), "ㄏㄠ")
        XCTAssertEqual(idx.reading(forCharacter: "你"), "ㄋㄧ")
    }

    func testReadingForCharacterPicksHighestScoredReading() {
        // 行 appears with two readings; the higher score (-2.0, ㄒㄧㄥ) must win over -5.0.
        let idx = TonelessLanguageModelIndex(text: """
        ㄒㄧㄥˊ 行 -2.0
        ㄏㄤˊ 行 -5.0
        """)
        XCTAssertEqual(idx.reading(forCharacter: "行"), "ㄒㄧㄥ")
    }

    func testReadingForCharacterNilWhenAbsent() {
        let idx = TonelessLanguageModelIndex(text: sample)
        XCTAssertNil(idx.reading(forCharacter: "電"))   // not in the sample
    }
}
