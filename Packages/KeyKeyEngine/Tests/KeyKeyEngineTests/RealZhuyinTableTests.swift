import XCTest
@testable import KeyKeyEngine

// Runs against the REAL bundled ㄅ半 table (Resources/zhuyin-yahoo.txt), the way the sibling
// Real*Tests run against the real 倉頡 one: the sample-text suites prove the parser, this proves
// the data a user actually types against.
final class RealZhuyinTableTests: XCTestCase {
    private func tableURL() -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Resources/zhuyin-yahoo.txt")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    private func realTable() throws -> ZhuyinTable {
        guard let url = tableURL() else { throw XCTSkip("Resources/zhuyin-yahoo.txt not present") }
        return try ZhuyinTable(contentsOf: url)
    }

    func testTheEverydayCharacterLeadsItsReading() throws {
        let table = try realTable()
        // The table's own order IS the built-in candidate order (there is no language-model rank
        // in 注音), so the first row of a common reading is what a typist gets for free. These are
        // the readings a first sentence uses.
        let expected: [(String, String)] = [
            ("ㄨㄛˇ", "我"), ("ㄋㄧˇ", "你"), ("ㄊㄚ", "它"), ("ㄉㄜ˙", "的"),
            ("ㄍㄨㄛˊ", "國"), ("ㄓㄨㄥ", "中"), ("ㄖㄣˊ", "人"), ("ㄕㄤˋ", "上"),
            ("ㄏㄠˇ", "好"), ("ㄧㄡˇ", "有"), ("ㄌㄞˊ", "來"), ("ㄎㄢˋ", "看"),
        ]
        for (reading, first) in expected {
            XCTAssertEqual(table.characters(forReading: reading).first, first,
                           "\(reading) should lead with \(first)")
        }
    }

    func testTonesAddressDifferentLists() throws {
        let table = try realTable()
        XCTAssertEqual(table.characters(forReading: "ㄕˋ").first, "市")
        XCTAssertTrue(table.characters(forReading: "ㄕˋ").contains("是"))
        XCTAssertFalse(table.characters(forReading: "ㄕ").contains("是"),
                       "是 is ㄕˋ; a toneless ㄕ must not offer it")
        XCTAssertTrue(table.characters(forReading: "ㄕ").contains("詩"))
    }

    func testAToneOnItsOwnIsNotAReading() throws {
        let table = try realTable()
        for mark in ["ˊ", "ˇ", "ˋ", "˙"] {
            XCTAssertFalse(table.hasReading(mark), "a bare tone key spells no syllable")
        }
    }

    func testCoverageIsTheWholeSyllableInventory() throws {
        let table = try realTable()
        // Mandarin has ~1,300 tone-bearing syllables in common use; the bundled table carries the
        // large character set, so anything far below this means the conversion dropped rows.
        XCTAssertGreaterThan(table.readingCount, 1_300)
        // Readings with no initial, with every medial, and the standalone ㄦ all parse.
        for reading in ["ㄦˊ", "ㄧ", "ㄨˋ", "ㄩˋ", "ㄠˋ", "ㄥ", "ㄤˊ"] {
            XCTAssertFalse(table.characters(forReading: reading).isEmpty,
                           "\(reading) should have at least one character")
        }
    }

    func testNoReadingOffersTheSameCharacterTwice() throws {
        let table = try realTable()
        for reading in ["ㄕˋ", "ㄧ", "ㄓ", "ㄉㄜ˙", "ㄨㄛˇ", "ㄋㄧˇ"] {
            let characters = table.characters(forReading: reading)
            XCTAssertEqual(characters.count, Set(characters).count,
                           "\(reading) lists a character more than once")
        }
    }

    // The engine against the real table: type 你好 the way a 大千 typist does.
    func testTypingAWordOnTheRealTable() throws {
        let table = try realTable()
        let engine = ZhuyinEngine(table: table, layout: .dachen)
        for key in "su3" { _ = engine.handleKey(key) }
        XCTAssertEqual(engine.composingText, "ㄋㄧˇ")
        XCTAssertEqual(engine.commit(), "你")
        for key in "cl3" { _ = engine.handleKey(key) }
        XCTAssertEqual(engine.composingText, "ㄏㄠˇ")
        XCTAssertEqual(engine.commit(), "好")
    }
}
