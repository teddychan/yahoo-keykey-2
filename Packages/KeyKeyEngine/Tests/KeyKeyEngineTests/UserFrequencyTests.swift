import XCTest
import Foundation
@testable import KeyKeyEngine

final class UserFrequencyTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("UserFrequencyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("user-frequency.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testUnseenCharHasZeroBonus() {
        let uf = UserFrequency(fileURL: fileURL)
        XCTAssertEqual(uf.bonus(for: "好"), 0)
    }

    func testRecordingIncreasesBonus() {
        let uf = UserFrequency(fileURL: fileURL)
        let before = uf.bonus(for: "好")
        uf.record("好")
        let after = uf.bonus(for: "好")
        XCTAssertGreaterThan(after, before)
    }

    func testMoreSelectionsGiveMoreBonus() {
        let uf = UserFrequency(fileURL: fileURL)
        uf.record("好")
        let oneHit = uf.bonus(for: "好")
        for _ in 0..<9 { uf.record("好") }
        let tenHits = uf.bonus(for: "好")
        XCTAssertGreaterThan(tenHits, oneHit)
    }

    func testBonusIsLargeEnoughToPromote() {
        // A few selections should produce a bonus on the order of the LM score span
        // (~12), enough to lift a learned char near the top of its candidate list.
        let uf = UserFrequency(fileURL: fileURL)
        for _ in 0..<3 { uf.record("好") }
        XCTAssertGreaterThan(uf.bonus(for: "好"), 10)
    }

    func testPersistenceRoundTrip() {
        let uf = UserFrequency(fileURL: fileURL)
        uf.record("好"); uf.record("好"); uf.record("字")
        let expectedHao = uf.bonus(for: "好")
        let expectedZi = uf.bonus(for: "字")

        // A fresh instance pointed at the same file must reload the counts.
        let reloaded = UserFrequency(fileURL: fileURL)
        XCTAssertEqual(reloaded.bonus(for: "好"), expectedHao)
        XCTAssertEqual(reloaded.bonus(for: "字"), expectedZi)
        XCTAssertEqual(reloaded.bonus(for: "X"), 0)
    }

    func testRecordPersistsToDisk() {
        let uf = UserFrequency(fileURL: fileURL)
        uf.record("好")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testMissingFileLoadsEmpty() {
        // Pointing at a non-existent file must fail safe to an empty store, no crash.
        let uf = UserFrequency(fileURL: tempDir.appendingPathComponent("does-not-exist.json"))
        XCTAssertEqual(uf.bonus(for: "好"), 0)
    }

    func testCorruptFileLoadsEmpty() throws {
        try "not json".data(using: .utf8)!.write(to: fileURL)
        let uf = UserFrequency(fileURL: fileURL)
        XCTAssertEqual(uf.bonus(for: "好"), 0)
    }
}
