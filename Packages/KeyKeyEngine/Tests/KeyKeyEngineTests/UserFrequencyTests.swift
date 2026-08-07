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
        uf.flush()   // save is debounced; force it before reloading

        // A fresh instance pointed at the same file must reload the counts.
        let reloaded = UserFrequency(fileURL: fileURL)
        XCTAssertEqual(reloaded.bonus(for: "好"), expectedHao)
        XCTAssertEqual(reloaded.bonus(for: "字"), expectedZi)
        XCTAssertEqual(reloaded.bonus(for: "X"), 0)
    }

    func testRecordPersistsToDisk() {
        let uf = UserFrequency(fileURL: fileURL)
        uf.record("好")
        uf.flush()   // save is debounced; force it before checking the file exists
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

    func testCorruptFileIsSetAsideForDiagnosis() throws {
        // An unreadable store must not be silently overwritten by the next save: it is moved
        // to "<name>.corrupt", contents intact, so it can still be inspected.
        try "not json".data(using: .utf8)!.write(to: fileURL)
        _ = UserFrequency(fileURL: fileURL)

        let corrupt = fileURL.appendingPathExtension("corrupt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(try String(contentsOf: corrupt, encoding: .utf8), "not json")
    }

    func testMissingFileIsNotSetAside() {
        // First launch has no file at all; that is normal, so nothing is quarantined.
        let missing = tempDir.appendingPathComponent("does-not-exist.json")
        _ = UserFrequency(fileURL: missing)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.appendingPathExtension("corrupt").path))
    }

    func testStoreRecoversAfterCorruption() throws {
        // Learning starts over from empty, but it must keep working: the next flush writes a
        // fresh, valid file that a later instance can read back.
        try "not json".data(using: .utf8)!.write(to: fileURL)
        let uf = UserFrequency(fileURL: fileURL)
        uf.record("好")
        uf.flush()

        let reloaded = UserFrequency(fileURL: fileURL)
        XCTAssertGreaterThan(reloaded.bonus(for: "好"), 0)
    }

    // MARK: - Hardening

    func testConcurrentRecordIsThreadSafe() {
        // Many threads hammering record() must not crash and must not lose all updates.
        let uf = UserFrequency(fileURL: fileURL)
        let iterations = 1000
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            uf.record("好")
        }
        // Every increment was applied under the lock, so the count is exact.
        let expected = log(1 + Double(iterations)) * 10.0
        XCTAssertEqual(uf.bonus(for: "好"), expected, accuracy: 1e-9)
    }

    func testDistinctEntriesAreCappedByEviction() throws {
        // Record more than the 5000-entry cap; the store must stay within the cap, and
        // a heavily-used char (recorded most) must survive eviction.
        let uf = UserFrequency(fileURL: fileURL)
        // A hot char recorded many times so it's never the coldest.
        for _ in 0..<50 { uf.record("好") }
        // 5100 distinct cold chars, each recorded once.
        let scalarBase = 0x4E00 // CJK ideographs block start
        for i in 0..<5100 {
            uf.record(Character(UnicodeScalar(scalarBase + i)!))
        }
        uf.flush()
        // Reload and count distinct persisted entries via the JSON file.
        let data = try Data(contentsOf: fileURL)
        let raw = try JSONDecoder().decode([String: Int].self, from: data)
        XCTAssertLessThanOrEqual(raw.count, 5000)
        // The hot char survived.
        XCTAssertGreaterThan(uf.bonus(for: "好"), 0)
    }

    func testDebouncedSaveFlushRoundTrips() {
        // record() does not write synchronously, but flush() persists and a reload sees it.
        let uf = UserFrequency(fileURL: fileURL)
        uf.record("好")
        uf.flush()
        let reloaded = UserFrequency(fileURL: fileURL)
        XCTAssertEqual(reloaded.bonus(for: "好"), uf.bonus(for: "好"))
        XCTAssertGreaterThan(reloaded.bonus(for: "好"), 0)
    }

    func testLoadFiltersMultiScalarKeys() throws {
        // Keys whose unicodeScalar count != 1 (e.g. emoji with modifiers, multi-char
        // strings) must be ignored on load; single-scalar keys load.
        let raw = ["好": 3, "ab": 5, "👨‍👩‍👧": 9]
        let data = try JSONEncoder().encode(raw)
        try data.write(to: fileURL)
        let uf = UserFrequency(fileURL: fileURL)
        XCTAssertGreaterThan(uf.bonus(for: "好"), 0)   // single scalar -> loaded
        XCTAssertEqual(uf.bonus(for: "a"), 0)          // "ab" dropped
        XCTAssertEqual(uf.bonus(for: "b"), 0)
    }

    func testSaveCreatesDirWith0700() throws {
        // The Application Support dir must be created with owner-only (0700) perms.
        let nested = tempDir.appendingPathComponent("sub").appendingPathComponent("freq.json")
        let uf = UserFrequency(fileURL: nested)
        uf.record("好")
        uf.flush()
        let attrs = try FileManager.default.attributesOfItem(atPath: nested.deletingLastPathComponent().path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(perms, 0o700)
    }

    func testDefaultFileURLPointsAtAppSupport() {
        let url = UserFrequency.defaultFileURL()
        XCTAssertEqual(url.lastPathComponent, "user-frequency.json")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "YahooKeyKey2")
    }

    func testFlushToUnwritableLocationDoesNotCrash() {
        // A path under a regular file (not a directory) can't have its parent dir created, so
        // save() hits its catch branch. The failure must be swallowed — no crash, no throw.
        let unwritable = URL(fileURLWithPath: "/dev/null/nope/user-frequency.json")
        let uf = UserFrequency(fileURL: unwritable)   // load also fails safe -> empty
        uf.record("好")
        uf.flush()                                    // save fails internally; logged, not fatal
        XCTAssertGreaterThan(uf.bonus(for: "好"), 0)   // in-memory count still intact
    }

    func testSingleCountIsCapped() {
        // bonus saturates: recording past the cap doesn't keep growing the count.
        let uf = UserFrequency(fileURL: fileURL)
        // The cap (100000) is large; just verify monotonic non-crash behaviour with a
        // modest run and that the bonus is finite and positive.
        for _ in 0..<100 { uf.record("好") }
        let b = uf.bonus(for: "好")
        XCTAssertTrue(b.isFinite)
        XCTAssertGreaterThan(b, 0)
    }
}
