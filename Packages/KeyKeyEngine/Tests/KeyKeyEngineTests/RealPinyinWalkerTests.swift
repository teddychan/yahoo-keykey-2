import XCTest
@testable import KeyKeyEngine

final class RealPinyinWalkerTests: XCTestCase {
    private func url(_ rel: String) -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let c = dir.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: c.path) { return c }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testKnownPhrasesResolve() throws {
        guard let dataURL = url("Resources/data.txt"),
              let mapURL = url("Resources/pinyin-zhuyin.txt") else {
            throw XCTSkip("data.txt / pinyin-zhuyin.txt not present")
        }
        let table = try PinyinSyllableTable(contentsOf: mapURL)
        let index = try TonelessLanguageModelIndex(contentsOf: dataURL)
        let engine = PinyinEngine(syllableTable: table, index: index)

        func type(_ s: String) -> String {
            _ = engine.commit()
            for c in s { _ = engine.handleKey(c) }
            let out = engine.composingText
            _ = engine.commit()
            return out
        }
        XCTAssertEqual(type("nihao"), "你好")
        XCTAssertEqual(type("womenqu"), "我們去")
        // Extra everyday phrases; values captured from the real LM/walker.
        XCTAssertEqual(type("zhongwen"), "中文")
        XCTAssertEqual(type("nihaoma"), "你好嗎")
        XCTAssertEqual(type("xiexie"), "謝謝")
    }
}
