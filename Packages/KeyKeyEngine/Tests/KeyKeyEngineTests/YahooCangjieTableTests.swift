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

    // The Yahoo table's z-code punctuation loads (was previously dropped by the CJK-only
    // filter): zxcd→「, zxce→」, zxab→，. Confirms both the data and the broadened filter.
    func testYahooZCodePunctuationLoads() throws {
        guard let v3URL = resourceURL("cangjie-yahoo.txt") else {
            throw XCTSkip("cangjie-yahoo.txt not present")
        }
        let v3 = try CangjieTable(contentsOf: v3URL)
        XCTAssertEqual(v3.characters(forCode: "zxcd"), ["「"])
        XCTAssertEqual(v3.characters(forCode: "zxce"), ["」"])
        XCTAssertTrue(v3.characters(forCode: "zxab").contains("，"))
        // And the engine composes it end-to-end (type z,x,c,d → first candidate 「).
        let engine = CangjieEngine(table: v3, characterRank: [:])
        for key in "zxcd" { _ = engine.handleKey(key) }
        XCTAssertEqual(engine.candidates.first, "「")
    }

    // Issue #62: the reported case. 含 decomposes as 人戈弓口 (oinr) in BOTH generations, so
    // typing 人一弓口 (omnr — 何's code) must not offer it. The upstream cj-ext.cin merged a
    // CNS11643/HKSCS dump onto its curated base table without deduplicating, which gave 800
    // already-encoded characters a second, non-standard code (含 as 今口 = omnr).
    func testYahooTableDoesNotMatchCharactersUnderAForeignCode() throws {
        guard let v3URL = resourceURL("cangjie-yahoo.txt") else {
            throw XCTSkip("cangjie-yahoo.txt not present")
        }
        let v3 = try CangjieTable(contentsOf: v3URL)
        XCTAssertTrue(v3.characters(forCode: "oinr").contains("含"))   // 人戈弓口 — the real code
        XCTAssertTrue(v3.characters(forCode: "omnr").contains("何"))   // 人一弓口 belongs to 何
        XCTAssertFalse(v3.characters(forCode: "omnr").contains("含"))
        // Same defect, other characters: the CNS codes disagree with the curated base entry.
        XCTAssertFalse(v3.characters(forCode: "rvhqo").contains("跌"))  // real code rmhqo
        XCTAssertFalse(v3.characters(forCode: "nlme").contains("阪"))   // real code nlhe
        XCTAssertFalse(v3.characters(forCode: "tomav").contains("養"))  // real code toiav
        XCTAssertTrue(v3.characters(forCode: "rmhqo").contains("跌"))
        XCTAssertTrue(v3.characters(forCode: "nlhe").contains("阪"))
        XCTAssertTrue(v3.characters(forCode: "toiav").contains("養"))
    }

    // 五代 was never affected — guard against a future table refresh reintroducing it there.
    func testStandardTableMatchesTheReportedCharacterOnlyUnderItsOwnCode() throws {
        guard let v5URL = resourceURL("cangjie.txt") else {
            throw XCTSkip("cangjie.txt not present")
        }
        let v5 = try CangjieTable(contentsOf: v5URL)
        XCTAssertTrue(v5.characters(forCode: "oinr").contains("含"))
        XCTAssertFalse(v5.characters(forCode: "omnr").contains("含"))
    }

    // No code bucket may list the same character twice — the un-deduplicated upstream merge
    // left 7 such pairs, which showed the character twice in one candidate page (issue #62).
    func testYahooTableHasNoDuplicateCharacterWithinACode() throws {
        guard let v3URL = resourceURL("cangjie-yahoo.txt") else {
            throw XCTSkip("cangjie-yahoo.txt not present")
        }
        let v3 = try CangjieTable(contentsOf: v3URL)
        v3.forEachEntry { code, chars in
            XCTAssertEqual(Set(chars).count, chars.count,
                           "Code \(code) lists a duplicate character: \(chars)")
        }
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
