import XCTest
import Foundation
@testable import KeyKeyEngine

// The per-candidate-list commit-count store (issue #130). Carries forward every reliability
// guarantee the retired per-character store had — thread safety, coalesced persistence, bounded
// storage, corrupt-file quarantine, fail-safe saves — and adds the one this store exists for:
// counts belong to ONE candidate list and must never be readable from another.
final class CandidateUsageStoreTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CandidateUsageStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = CandidateUsageStore.defaultFileURL(directory: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func store() -> CandidateUsageStore { CandidateUsageStore(fileURL: fileURL) }

    // MARK: - Counting

    func testUnseenCandidateHasZeroCount() {
        XCTAssertEqual(store().count(of: "日", in: .simplex(tableVersion: "5", code: "a")), 0)
    }

    func testRecordIncrementsImmediately() {
        let s = store()
        let list = CandidateListKey.simplex(tableVersion: "5", code: "a")
        s.record("日", in: list)
        XCTAssertEqual(s.count(of: "日", in: list), 1)
        s.record("日", in: list)
        XCTAssertEqual(s.count(of: "日", in: list), 2)
    }

    func testRecordingOneCandidateLeavesTheOthersInItsListAtZero() {
        let s = store()
        let list = CandidateListKey.simplex(tableVersion: "5", code: "a")
        s.record("日", in: list)
        XCTAssertEqual(s.count(of: "曰", in: list), 0)
    }

    // MARK: - List identity: exact 倉頡 (spec: isolated by table version and code)

    func testExactCangjieHistoriesAreIsolatedByTableVersion() {
        let s = store()
        s.record("日", in: .cangjie(tableVersion: "5", code: "a"))
        XCTAssertEqual(s.count(of: "日", in: .cangjie(tableVersion: "5", code: "a")), 1)
        // 三代 and 五代 answer `a` with different characters, so they are different lists.
        XCTAssertEqual(s.count(of: "日", in: .cangjie(tableVersion: "3", code: "a")), 0)
    }

    func testExactCangjieHistoriesAreIsolatedByCode() {
        let s = store()
        s.record("日", in: .cangjie(tableVersion: "5", code: "a"))
        XCTAssertEqual(s.count(of: "日", in: .cangjie(tableVersion: "5", code: "ab")), 0)
    }

    func testCommittingUnderAnotherModeDoesNotTouchTheExactCangjieList() {
        let s = store()
        s.record("日", in: .simplex(tableVersion: "5", code: "a"))
        s.record("日", in: .pinyin(readingKey: "ㄖˋ"))
        s.record("日日", in: .association(trigger: "日"))
        XCTAssertEqual(s.count(of: "日", in: .cangjie(tableVersion: "5", code: "a")), 0)
    }

    // MARK: - List identity: 倉頡 wildcard (spec: isolated from exact codes and other patterns)

    func testWildcardHistoryIsIsolatedFromTheExactCode() {
        let s = store()
        // 竹*戈 is internally h*i.
        s.record("龍", in: .cangjieWildcard(tableVersion: "5", pattern: "h*i"))
        XCTAssertEqual(s.count(of: "龍", in: .cangjieWildcard(tableVersion: "5", pattern: "h*i")), 1)
        XCTAssertEqual(s.count(of: "龍", in: .cangjie(tableVersion: "5", code: "h*i")), 0)
        XCTAssertEqual(s.count(of: "龍", in: .cangjie(tableVersion: "5", code: "hi")), 0)
    }

    func testWildcardHistoriesAreIsolatedFromOtherPatterns() {
        let s = store()
        s.record("龍", in: .cangjieWildcard(tableVersion: "5", pattern: "h*i"))
        XCTAssertEqual(s.count(of: "龍", in: .cangjieWildcard(tableVersion: "5", pattern: "h*e")), 0)
        XCTAssertEqual(s.count(of: "龍", in: .cangjieWildcard(tableVersion: "5", pattern: "*i")), 0)
        XCTAssertEqual(s.count(of: "龍", in: .cangjieWildcard(tableVersion: "3", pattern: "h*i")), 0)
    }

    // MARK: - List identity: 速成 (spec: isolated by table version and code)

    func testSimplexHistoriesAreIsolatedByTableVersionAndCode() {
        let s = store()
        s.record("曰", in: .simplex(tableVersion: "5", code: "a"))
        XCTAssertEqual(s.count(of: "曰", in: .simplex(tableVersion: "5", code: "a")), 1)
        XCTAssertEqual(s.count(of: "曰", in: .simplex(tableVersion: "3", code: "a")), 0)
        XCTAssertEqual(s.count(of: "曰", in: .simplex(tableVersion: "5", code: "ab")), 0)
    }

    // MARK: - List identity: 聯想字詞 (spec: shared across modes, keyed by the full phrase)

    func testAssociationCountsAreKeyedByTheFullPhrase() {
        let s = store()
        s.record("關係", in: .association(trigger: "關"))
        XCTAssertEqual(s.count(of: "關係", in: .association(trigger: "關")), 1)
        // Not the continuation on its own, which is only what the display may shorten to.
        XCTAssertEqual(s.count(of: "係", in: .association(trigger: "關")), 0)
    }

    func testAssociationListsAreIsolatedByTrigger() {
        let s = store()
        s.record("關係", in: .association(trigger: "關"))
        XCTAssertEqual(s.count(of: "關係", in: .association(trigger: "心")), 0)
    }

    func testAssociationKeyCarriesNoModeSoOneListIsShared() {
        // The key has no mode field at all, which is what makes 倉頡 and 速成 share the list:
        // a phrase committed after entering 關 in one mode is the same record in the other.
        let s = store()
        s.record("關係", in: .association(trigger: "關"))
        s.record("關係", in: .association(trigger: "關"))
        XCTAssertEqual(s.count(of: "關係", in: .association(trigger: "關")), 2)
    }

    // MARK: - Persistence (spec: reload retains counts and list identities)

    func testReloadRetainsCountsAndListIdentities() {
        let s = store()
        s.record("曰", in: .simplex(tableVersion: "5", code: "a"))
        s.record("曰", in: .simplex(tableVersion: "5", code: "a"))
        s.record("日", in: .cangjie(tableVersion: "3", code: "a"))
        s.record("龍", in: .cangjieWildcard(tableVersion: "5", pattern: "h*i"))
        s.record("你好", in: .pinyin(readingKey: "ㄋㄧ-ㄏㄠ"))
        s.record("關係", in: .association(trigger: "關"))
        s.flush()   // the save is debounced; force it before reading the file back

        let r = CandidateUsageStore(fileURL: fileURL)
        XCTAssertEqual(r.count(of: "曰", in: .simplex(tableVersion: "5", code: "a")), 2)
        XCTAssertEqual(r.count(of: "日", in: .cangjie(tableVersion: "3", code: "a")), 1)
        XCTAssertEqual(r.count(of: "龍", in: .cangjieWildcard(tableVersion: "5", pattern: "h*i")), 1)
        XCTAssertEqual(r.count(of: "你好", in: .pinyin(readingKey: "ㄋㄧ-ㄏㄠ")), 1)
        XCTAssertEqual(r.count(of: "關係", in: .association(trigger: "關")), 1)
        // The identities survive too — a reloaded store still isolates every list.
        XCTAssertEqual(r.count(of: "曰", in: .simplex(tableVersion: "3", code: "a")), 0)
        XCTAssertEqual(r.count(of: "日", in: .cangjie(tableVersion: "5", code: "a")), 0)
        XCTAssertEqual(r.count(of: "日", in: .simplex(tableVersion: "3", code: "a")), 0)
        XCTAssertEqual(r.count(of: "龍", in: .cangjieWildcard(tableVersion: "5", pattern: "h*e")), 0)
    }

    func testAReloadedCountKeepsIncrementing() {
        let s = store()
        let list = CandidateListKey.simplex(tableVersion: "5", code: "a")
        s.record("曰", in: list)
        s.flush()
        let r = CandidateUsageStore(fileURL: fileURL)
        r.record("曰", in: list)
        XCTAssertEqual(r.count(of: "曰", in: list), 2)
    }

    func testRecordPersistsToDisk() {
        let s = store()
        s.record("日", in: .simplex(tableVersion: "5", code: "a"))
        s.flush()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testPersistedFileIsVersioned() throws {
        let s = store()
        s.record("日", in: .simplex(tableVersion: "5", code: "a"))
        s.flush()
        let json = try JSONSerialization.jsonObject(with: try Data(contentsOf: fileURL))
        let version = (json as? [String: Any])?["version"] as? Int
        XCTAssertEqual(version, CandidateUsageStore.formatVersion)
    }

    func testAFreshStoreStartsEmptyRatherThanInheritingLegacyCounts() throws {
        // The retired store's global per-character counts carry no list identity, so they are
        // deliberately NOT migrated: a legacy file sitting in the same directory must leave the
        // new store empty rather than being read as though its counts belonged to some list.
        let legacy = CandidateUsageStore.legacyFileURL(directory: tempDir)
        try Data(#"{"日":40,"曰":9}"#.utf8).write(to: legacy)
        let s = store()
        XCTAssertEqual(s.count(of: "日", in: .simplex(tableVersion: "5", code: "a")), 0)
        XCTAssertEqual(s.count(of: "日", in: .cangjie(tableVersion: "5", code: "a")), 0)
        // And the legacy file is left alone, so a downgrade still finds its data.
        XCTAssertEqual(try String(contentsOf: legacy, encoding: .utf8), #"{"日":40,"曰":9}"#)
    }

    // MARK: - Safe recovery

    func testMissingFileLoadsEmpty() {
        let s = CandidateUsageStore(fileURL: tempDir.appendingPathComponent("does-not-exist.json"))
        XCTAssertEqual(s.count(of: "日", in: .simplex(tableVersion: "5", code: "a")), 0)
    }

    func testMissingFileIsNotSetAside() {
        // First launch has no file at all; that is normal, so nothing is quarantined.
        let missing = tempDir.appendingPathComponent("does-not-exist.json")
        _ = CandidateUsageStore(fileURL: missing)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.appendingPathExtension("corrupt").path))
    }

    func testCorruptFileLoadsEmpty() throws {
        try Data("not json".utf8).write(to: fileURL)
        XCTAssertEqual(store().count(of: "日", in: .simplex(tableVersion: "5", code: "a")), 0)
    }

    func testCorruptFileIsSetAsideForDiagnosis() throws {
        // An unreadable store must not be silently overwritten by the next save: it is moved to
        // "<name>.corrupt", contents intact, so it can still be inspected.
        try Data("not json".utf8).write(to: fileURL)
        _ = store()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(try String(contentsOf: fileURL.appendingPathExtension("corrupt"), encoding: .utf8),
                       "not json")
    }

    func testAFileFromAnUnknownFormatVersionIsSetAsideNotParsed() throws {
        // A file written by a newer build must not be read as though it were this format, and
        // must not be overwritten in place either — it is preserved alongside.
        try Data(#"{"version":99,"lists":[{"scope":"simplex","tableVersion":"5","code":"a","counts":{"日":7}}]}"#.utf8)
            .write(to: fileURL)
        let s = store()
        XCTAssertEqual(s.count(of: "日", in: .simplex(tableVersion: "5", code: "a")), 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.appendingPathExtension("corrupt").path))
    }

    func testStoreRecoversAfterCorruption() throws {
        // Counting starts over from empty, but it must keep working: the next flush writes a
        // fresh, valid file that a later instance can read back.
        try Data("not json".utf8).write(to: fileURL)
        let s = store()
        let list = CandidateListKey.simplex(tableVersion: "5", code: "a")
        s.record("日", in: list)
        s.flush()
        XCTAssertEqual(CandidateUsageStore(fileURL: fileURL).count(of: "日", in: list), 1)
    }

    func testARecordNamingAnUnknownScopeIsDroppedNotMisfiled() throws {
        try Data(#"{"version":1,"lists":[{"scope":"bopomofo","code":"a","counts":{"日":9}}]}"#.utf8)
            .write(to: fileURL)
        let s = store()
        XCTAssertEqual(s.count(of: "日", in: .cangjie(tableVersion: "5", code: "a")), 0)
        XCTAssertEqual(s.count(of: "日", in: .simplex(tableVersion: "5", code: "a")), 0)
        XCTAssertEqual(s.count(of: "日", in: .pinyin(readingKey: "a")), 0)
    }

    func testARecordMissingARequiredFieldIsDroppedNotMisfiled() throws {
        // A 倉頡 record with no table version cannot say WHICH list it belongs to, so it is
        // dropped rather than defaulted into one of them.
        try Data(#"{"version":1,"lists":[{"scope":"cangjie","code":"a","counts":{"日":9}}]}"#.utf8)
            .write(to: fileURL)
        let s = store()
        XCTAssertEqual(s.count(of: "日", in: .cangjie(tableVersion: "5", code: "a")), 0)
        XCTAssertEqual(s.count(of: "日", in: .cangjie(tableVersion: "3", code: "a")), 0)
    }

    func testFlushToUnwritableLocationDoesNotCrash() {
        // A path under a regular file (not a directory) can't have its parent dir created, so
        // save() hits its catch branch. The failure must be swallowed — no crash, no throw.
        let unwritable = URL(fileURLWithPath: "/dev/null/nope/candidate-usage.json")
        let s = CandidateUsageStore(fileURL: unwritable)   // load also fails safe -> empty
        let list = CandidateListKey.simplex(tableVersion: "5", code: "a")
        s.record("日", in: list)
        s.flush()                                          // save fails internally; logged, not fatal
        XCTAssertEqual(s.count(of: "日", in: list), 1)      // in-memory count still intact
    }

    // MARK: - Hardening (thread safety, bounds)

    func testConcurrentRecordIsThreadSafe() {
        // Many threads hammering record() must not crash and must not lose updates: every
        // increment is applied under the lock, so the count is exact.
        let s = store()
        let list = CandidateListKey.simplex(tableVersion: "5", code: "a")
        let iterations = 1000
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in s.record("日", in: list) }
        XCTAssertEqual(s.count(of: "日", in: list), iterations)
    }

    func testConcurrentRecordsAcrossDifferentListsStayInTheirOwnList() {
        let s = store()
        let iterations = 400
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            s.record("日", in: .simplex(tableVersion: i.isMultiple(of: 2) ? "5" : "3", code: "a"))
        }
        XCTAssertEqual(s.count(of: "日", in: .simplex(tableVersion: "5", code: "a")), iterations / 2)
        XCTAssertEqual(s.count(of: "日", in: .simplex(tableVersion: "3", code: "a")), iterations / 2)
    }

    func testConcurrentReadsAndWritesDoNotCrash() {
        let s = store()
        let list = CandidateListKey.simplex(tableVersion: "5", code: "a")
        DispatchQueue.concurrentPerform(iterations: 500) { i in
            if i.isMultiple(of: 2) { s.record("日", in: list) } else { _ = s.count(of: "日", in: list) }
        }
        XCTAssertGreaterThan(s.count(of: "日", in: list), 0)
    }

    func testDistinctRecordsAreCappedByEviction() {
        // Record past the cap; the store must stay within it, and a heavily-committed candidate
        // must survive eviction (it is never the coldest).
        let s = store()
        let hot = CandidateListKey.simplex(tableVersion: "5", code: "a")
        for _ in 0..<50 { s.record("日", in: hot) }
        for i in 0..<(CandidateUsageStore.maxEntries + 200) {
            s.record("x", in: .cangjie(tableVersion: "5", code: "cold\(i)"))
        }
        XCTAssertLessThanOrEqual(s.entryCountForTesting, CandidateUsageStore.maxEntries)
        XCTAssertEqual(s.count(of: "日", in: hot), 50)
    }

    func testEvictionIsDeterministic() {
        // Two stores fed the same commits must hold the same records, so the on-disk contents
        // do not depend on dictionary iteration order.
        func fill() -> CandidateUsageStore {
            let s = CandidateUsageStore(fileURL: tempDir.appendingPathComponent("\(UUID().uuidString).json"))
            for i in 0..<(CandidateUsageStore.maxEntries + 50) {
                s.record("x", in: .cangjie(tableVersion: "5", code: "c\(i)"))
            }
            return s
        }
        let a = fill(), b = fill()
        XCTAssertEqual(a.entryCountForTesting, b.entryCountForTesting)
        for i in 0..<(CandidateUsageStore.maxEntries + 50) {
            let list = CandidateListKey.cangjie(tableVersion: "5", code: "c\(i)")
            XCTAssertEqual(a.count(of: "x", in: list), b.count(of: "x", in: list),
                           "eviction differed for c\(i)")
        }
    }

    func testSingleCountIsCapped() {
        let s = store()
        let list = CandidateListKey.simplex(tableVersion: "5", code: "a")
        for _ in 0..<100 { s.record("日", in: list) }
        XCTAssertEqual(s.count(of: "日", in: list), 100)
        XCTAssertLessThanOrEqual(s.count(of: "日", in: list), CandidateUsageStore.maxCount)
    }

    func testALoadedCountIsClampedToTheCap() throws {
        try Data(#"{"version":1,"lists":[{"scope":"simplex","tableVersion":"5","code":"a","counts":{"日":999999999}}]}"#.utf8)
            .write(to: fileURL)
        XCTAssertEqual(store().count(of: "日", in: .simplex(tableVersion: "5", code: "a")),
                       CandidateUsageStore.maxCount)
    }

    // MARK: - On-disk location

    // A local debug build passes its own directory name so it can't read, train, or (via the
    // Uninstall pane) delete the installed release IME's learning data — the one piece of KeyKey
    // state the `.debug` bundle id does not separate on its own. The release name must keep
    // resolving where it always did. Both names are spelled out because neither is a default:
    // the parameter is required so no build can reach the release directory by omitting one.
    func testNamedSupportDirectoryIsDistinctFromTheReleaseDefault() {
        let release = CandidateUsageStore.supportDirectory(named: "YahooKeyKey2")
        let debug = CandidateUsageStore.supportDirectory(named: "YahooKeyKey2 Debug")
        XCTAssertEqual(release.lastPathComponent, "YahooKeyKey2")
        XCTAssertNotEqual(release, debug)
        XCTAssertEqual(release.deletingLastPathComponent(), debug.deletingLastPathComponent())
        XCTAssertEqual(CandidateUsageStore.defaultFileURL(directory: debug),
                       debug.appendingPathComponent("candidate-usage.json"))
    }

    // The Uninstall pane removes SharedResources.supportDirectory, one directory. Both learning
    // files must therefore sit directly inside it, or uninstalling would leave one behind.
    func testBothLearningFilesLiveInTheDirectoryUninstallRemoves() {
        let dir = CandidateUsageStore.supportDirectory(named: "YahooKeyKey2")
        let new = CandidateUsageStore.defaultFileURL(directory: dir)
        let legacy = CandidateUsageStore.legacyFileURL(directory: dir)
        XCTAssertEqual(new.lastPathComponent, "candidate-usage.json")
        XCTAssertEqual(legacy.lastPathComponent, "user-frequency.json")
        XCTAssertNotEqual(new, legacy)
        // Compared as PATHS, not as URLs. `appendingPathComponent` appends a trailing slash only
        // when the component already exists on disk as a directory, while
        // `deletingLastPathComponent` always adds one — so a URL comparison here passes on a Mac
        // that has the support directory and fails on one that does not, which is exactly how it
        // passed locally and failed on a clean CI runner. `path` normalises the slash away.
        XCTAssertEqual(new.deletingLastPathComponent().path, dir.path)
        XCTAssertEqual(legacy.deletingLastPathComponent().path, dir.path)
    }
}
