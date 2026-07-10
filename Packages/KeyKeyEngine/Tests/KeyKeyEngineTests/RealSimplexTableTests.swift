import XCTest
@testable import KeyKeyEngine

// Runs only when Resources/cangjie.txt is present (the bundled real Cangjie 5 table).
// The shipped Simplex table has no dedicated resource file -- like SharedResources.swift,
// it's derived from the real Cangjie table via SimplexTable(cangjie:).
final class RealSimplexTableTests: XCTestCase {
    private func tableURL() -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Resources/cangjie.txt")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testRealTableDerivesAndLooksUpCommonCharacters() throws {
        guard let url = tableURL() else {
            throw XCTSkip("Resources/cangjie.txt not present")
        }
        let cangjie = try CangjieTable(contentsOf: url)
        let simplex = SimplexTable(cangjie: cangjie)
        // 日 is encoded by a single "a" radical -> simplex "a"; 明 by "ab" (日月) -> simplex "ab".
        XCTAssertTrue(simplex.characters(forCode: "a").contains("日"))
        XCTAssertTrue(simplex.characters(forCode: "ab").contains("明"))
    }
}
