import XCTest
@testable import KeyKeyEngine

// Runs only when Resources/cangjie.txt is present (the bundled real Cangjie 5 table).
// Loaded lazily by path so the unit tests above stay independent of the large file.
final class RealCangjieTableTests: XCTestCase {
    private func tableURL() -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Resources/cangjie.txt")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testRealTableLoadsAndLooksUpCommonCharacters() throws {
        guard let url = tableURL() else {
            throw XCTSkip("Resources/cangjie.txt not present")
        }
        let table = try CangjieTable(contentsOf: url)
        // 日 is encoded by a single "a" radical; 明 by "ab" (日月).
        XCTAssertTrue(table.characters(forCode: "a").contains("日"))
        XCTAssertTrue(table.characters(forCode: "ab").contains("明"))

        let e = CangjieEngine(table: table, tableVersion: "5")
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.composingText, "日月")
        XCTAssertTrue(e.candidates.contains("明"))
    }

    func testRealTableContainsNoTofuCharacters() throws {
        guard let url = tableURL() else {
            throw XCTSkip("Resources/cangjie.txt not present")
        }
        let table = try CangjieTable(contentsOf: url)
        var checked = 0
        table.forEachEntry { _, chars in
            for char in chars {
                XCTAssertTrue(
                    char.count == 1 && CangjieTable.isRenderableCJK(char.first!),
                    "Tofu/unrenderable character survived the load-time filter: \(char.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined())"
                )
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }
}
