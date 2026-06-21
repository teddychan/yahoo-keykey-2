import XCTest
@testable import KeyKeyEngine

// Runs only when Resources/data.txt exists (built by tools/build-lm.sh).
final class RealLMValidationTests: XCTestCase {
    private func dataURL() -> URL? {
        // walk up from this file to repo root, then Resources/data.txt
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Resources/data.txt")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testRealLMLoadsAndComposesCommonWord() throws {
        guard let url = dataURL() else {
            throw XCTSkip("Resources/data.txt not built; run tools/build-lm.sh")
        }
        let lm = try LanguageModel(contentsOf: url)
        // 今天 (jin-tian) is a high-frequency word; expect it present and on the best path.
        XCTAssertTrue(lm.hasKey("ㄐㄧㄣ-ㄊㄧㄢ"))
        let grid = ReadingGrid(readings: ["ㄐㄧㄣ", "ㄊㄧㄢ"], languageModel: lm)
        XCTAssertEqual(grid.walk().joined(), "今天")
    }

    func testHeaderPresent() throws {
        guard let url = dataURL() else { throw XCTSkip("data.txt not built") }
        let first = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n").first.map(String.init) ?? ""
        XCTAssertEqual(first, "# format org.openvanilla.mcbopomofo.sorted")
    }
}
