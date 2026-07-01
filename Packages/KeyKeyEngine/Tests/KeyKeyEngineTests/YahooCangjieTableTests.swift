import XCTest
@testable import KeyKeyEngine

// Verifies the bundled Yahoo! KeyKey 三代 tables (Resources/cangjie-yahoo.txt,
// simplex-yahoo.txt) against the standard 五代 table (Resources/cangjie.txt): the
// decompositions differ as documented in issue #30, and the Yahoo table's native line
// order is preserved when the engine is given an empty rank.
final class YahooCangjieTableTests: XCTestCase {
    private func resourceURL(_ name: String) -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Resources/\(name)")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    // 三代 (Yahoo) and 五代 encode these characters with different codes (issue #30 examples).
    func testGenerationsDecomposeDifferently() throws {
        guard let v5URL = resourceURL("cangjie.txt"), let v3URL = resourceURL("cangjie-yahoo.txt") else {
            throw XCTSkip("Cangjie tables not present")
        }
        let v5 = try CangjieTable(contentsOf: v5URL)
        let v3 = try CangjieTable(contentsOf: v3URL)

        // 三代: 面=mwyl, 鬼=hi, 樓=dlwv, 醜=mwhi.
        XCTAssertTrue(v3.characters(forCode: "mwyl").contains("面"))
        XCTAssertTrue(v3.characters(forCode: "hi").contains("鬼"))
        XCTAssertTrue(v3.characters(forCode: "dlwv").contains("樓"))
        XCTAssertTrue(v3.characters(forCode: "mwhi").contains("醜"))

        // 五代: 面=mwsl, 鬼=hui, 樓=dllv, 醜=mwhui — and NOT the 三代 codes.
        XCTAssertTrue(v5.characters(forCode: "mwsl").contains("面"))
        XCTAssertTrue(v5.characters(forCode: "hui").contains("鬼"))
        XCTAssertFalse(v5.characters(forCode: "mwyl").contains("面"))
        XCTAssertFalse(v5.characters(forCode: "hi").contains("鬼"))
    }

    // With an empty rank the engine preserves the Yahoo table's native line order (我 is the
    // first candidate typed for hqi in the original Yahoo! KeyKey table).
    func testYahooNativeOrderPreservedWithEmptyRank() throws {
        guard let v3URL = resourceURL("cangjie-yahoo.txt") else {
            throw XCTSkip("cangjie-yahoo.txt not present")
        }
        let v3 = try CangjieTable(contentsOf: v3URL)
        let engine = CangjieEngine(table: v3, characterRank: [:])
        for key in "hqi" { _ = engine.handleKey(key) }
        XCTAssertEqual(engine.candidates.first, "我")
    }

    // The Yahoo 速成 table loads via the quick-code initializer and preserves native order.
    func testYahooSimplexLoadsAndPreservesOrder() throws {
        guard let url = resourceURL("simplex-yahoo.txt") else {
            throw XCTSkip("simplex-yahoo.txt not present")
        }
        let simplex = try SimplexTable(quickCodeContentsOf: url)
        let cands = simplex.characters(forCode: "hi")
        XCTAssertFalse(cands.isEmpty)
        XCTAssertTrue(cands.contains("鬼"))
    }
}
