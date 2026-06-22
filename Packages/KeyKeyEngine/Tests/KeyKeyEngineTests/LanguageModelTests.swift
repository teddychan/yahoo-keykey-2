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

    func testCharacterScoresKeepsSingleCharsAndMaxScore() {
        let lm = LanguageModel(text: Self.fixture)
        let scores = lm.characterScores()
        // Single-char values only; multi-char "貓咪" excluded.
        XCTAssertEqual(Set(scores.keys), Set(["八", "吧", "貓"]))
        // 貓 appears once at -4.1.
        XCTAssertEqual(scores["貓"] ?? 0, -4.10000000, accuracy: 1e-6)
    }

    func testCharacterScoresRecordsMaxAcrossEntries() {
        // 我 appears under two readings with different scores; keep the larger.
        let lm = LanguageModel(text: """
        ㄨㄛ 我 -5.00000000
        ㄜ 我 -3.00000000
        """)
        XCTAssertEqual(lm.characterScores()["我"] ?? 0, -3.00000000, accuracy: 1e-6)
    }
}
