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

    func testReverseZhuyinToPinyin() {
        let table = PinyinSyllableTable(text: "hao\tㄏㄠ\nni\tㄋㄧ\nwo\tㄨㄛ")
        XCTAssertEqual(table.pinyin(forZhuyin: "ㄏㄠ"), "hao")
        XCTAssertEqual(table.pinyin(forZhuyin: "ㄨㄛ"), "wo")
        XCTAssertNil(table.pinyin(forZhuyin: "ㄗ"))
    }
}

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
