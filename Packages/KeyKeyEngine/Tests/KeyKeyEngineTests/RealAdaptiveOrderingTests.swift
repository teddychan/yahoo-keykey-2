import XCTest
@testable import KeyKeyEngine

// Adaptive ordering (issue #130) against the REAL bundled tables and language model, so the
// behaviour is pinned on the data users actually type against rather than on fixtures. Skips
// when the resources are absent — `Resources/data.txt` is generated, not committed.
final class RealAdaptiveOrderingTests: XCTestCase {
    private func url(_ rel: String) -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let c = dir.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: c.path) { return c }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    private struct Fixtures {
        let cangjie: CangjieTable
        let yahoo: CangjieTable
        let simplex: SimplexTable
        let rank: [Character: Double]
        let associations: AssociatedPhrases
    }

    private func load() throws -> Fixtures {
        guard let cangjieURL = url("Resources/cangjie.txt"),
              let yahooURL = url("Resources/cangjie-yahoo.txt"),
              let dataURL = url("Resources/data.txt") else {
            throw XCTSkip("Resources/cangjie.txt, cangjie-yahoo.txt or data.txt not present")
        }
        let cangjie = try CangjieTable(contentsOf: cangjieURL)
        let text = try String(contentsOf: dataURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        return Fixtures(cangjie: cangjie,
                        yahoo: try CangjieTable(contentsOf: yahooURL),
                        simplex: SimplexTable(cangjie: cangjie),
                        rank: LanguageModel.characterScores(fromLines: lines),
                        associations: AssociatedPhrases(lines: lines))
    }

    // MARK: - The real 速成 `a` list: 日 / 曰

    func testRealSimplexAListRespondsToItsOwnCounts() throws {
        let f = try load()
        // The list the spec names, straight out of the shipped table.
        XCTAssertEqual(f.simplex.characters(forCode: "a"), ["日", "曰"])

        func order(_ counts: [String: Int]) -> [String] {
            let e = SimplexEngine(table: f.simplex, characterRank: f.rank, tableVersion: "5",
                                  usageCount: { _, c in counts[c] ?? 0 })
            _ = e.handleKey("a")
            return e.candidates
        }
        // Untrained: the built-in order (日 outranks 曰 in the language model).
        XCTAssertEqual(order([:]), ["日", "曰"])
        // 日 five commits, 曰 seven: 曰 leads.
        XCTAssertEqual(order(["日": 5, "曰": 7]), ["曰", "日"])
        // Both five: the built-in order again — never recency.
        XCTAssertEqual(order(["日": 5, "曰": 5]), ["日", "曰"])
        // One commit of 曰 alone is enough to lead the untrained 日.
        XCTAssertEqual(order(["曰": 1]), ["曰", "日"])
    }

    func testACommitInTheRealSimplexAListIncrementsThatListOnly() throws {
        let f = try load()
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RealAdaptive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = CandidateUsageStore(fileURL: CandidateUsageStore.defaultFileURL(directory: dir))

        // Type `a`, pick 日, commit — the way any commit path does it.
        let e = SimplexEngine(table: f.simplex, characterRank: f.rank, tableVersion: "5",
                              usageCount: { store.count(of: $1, in: $0) })
        _ = e.handleKey("a")
        e.selectCandidate(0)
        let pending = e.pendingUsage
        XCTAssertEqual(e.commit(), "日")
        for usage in pending { store.record(usage.candidate, in: usage.list) }

        XCTAssertEqual(store.count(of: "日", in: .simplex(tableVersion: "5", code: "a")), 1)
        // Nowhere else: not the 倉頡 list of the same code, not the other table version.
        XCTAssertEqual(store.count(of: "日", in: .cangjie(tableVersion: "5", code: "a")), 0)
        XCTAssertEqual(store.count(of: "日", in: .simplex(tableVersion: "3", code: "a")), 0)
    }

    // MARK: - A language-model-unranked character leading a ranked one (known issue #6)

    func testRealUnrankedVariantLeadsARankedCharacterAfterOneCommit() throws {
        let f = try load()
        // 卜月卜尸心 = ybysp: 龍 is in the language model, the variant 㡣 is not. This is the
        // list known issue #6 was written about.
        XCTAssertEqual(f.cangjie.characters(forCode: "ybysp"), ["龍", "㡣"])
        XCTAssertNotNil(f.rank["龍"])
        XCTAssertNil(f.rank["㡣"], "㡣 is expected to be absent from the language model")

        func order(_ counts: [String: Int]) -> [String] {
            let e = CangjieEngine(table: f.cangjie, characterRank: f.rank, tableVersion: "5",
                                  usageCount: { _, c in counts[c] ?? 0 })
            for k in "ybysp" { _ = e.handleKey(k) }
            return e.candidates
        }
        XCTAssertEqual(order([:]), ["龍", "㡣"])              // untrained: the ranked one leads
        XCTAssertEqual(order(["㡣": 1]), ["㡣", "龍"])         // one commit is enough
        XCTAssertEqual(order(["㡣": 1, "龍": 1]), ["龍", "㡣"]) // equal counts: built-in order back
        XCTAssertEqual(order(["㡣": 2, "龍": 5]), ["龍", "㡣"]) // the more-committed one stays ahead
    }

    // MARK: - Wildcard lists are their own (real `竹*戈`)

    func testRealWildcardListIsSeparateFromTheExactCode() throws {
        let f = try load()
        // 竹*戈 is h*i; the exact code hi is a different, much shorter list.
        let wildcard = f.cangjie.characters(matching: "h*i")
        let exact = f.cangjie.characters(forCode: "hi")
        XCTAssertGreaterThan(wildcard.count, exact.count)
        XCTAssertEqual(exact, ["么", "䇝"])

        var asked: Set<CandidateListKey> = []
        let e = CangjieEngine(table: f.cangjie, characterRank: f.rank, tableVersion: "5",
                              usageCount: { list, _ in asked.insert(list); return 0 })
        for k in "h*i" { _ = e.handleKey(k) }
        XCTAssertEqual(e.candidateListKey, .cangjieWildcard(tableVersion: "5", pattern: "h*i"))
        _ = e.candidates
        XCTAssertEqual(asked, [.cangjieWildcard(tableVersion: "5", pattern: "h*i")])
        XCTAssertFalse(asked.contains(.cangjie(tableVersion: "5", code: "hi")))

        // A count under the wildcard pattern reorders the wildcard list. The target is the
        // list's LAST candidate, so leading is a real move rather than a coincidence.
        let baseline = wildcardBaseline(f)
        let target = try XCTUnwrap(baseline.last)
        XCTAssertNotEqual(target, baseline.first)
        let trained = CangjieEngine(table: f.cangjie, characterRank: f.rank, tableVersion: "5",
                                    usageCount: { list, c in
            list == .cangjieWildcard(tableVersion: "5", pattern: "h*i") && c == target ? 1 : 0
        })
        for k in "h*i" { _ = trained.handleKey(k) }
        XCTAssertEqual(trained.candidates.first, target)

        // ...but the same count filed under a DIFFERENT pattern moves nothing.
        let other = CangjieEngine(table: f.cangjie, characterRank: f.rank, tableVersion: "5",
                                  usageCount: { list, c in
            list == .cangjieWildcard(tableVersion: "5", pattern: "h*e") && c == target ? 1 : 0
        })
        for k in "h*i" { _ = other.handleKey(k) }
        XCTAssertEqual(other.candidates, baseline)
    }

    private func wildcardBaseline(_ f: Fixtures) -> [String] {
        let e = CangjieEngine(table: f.cangjie, characterRank: f.rank, tableVersion: "5")
        for k in "h*i" { _ = e.handleKey(k) }
        return e.candidates
    }

    // MARK: - 聯想字詞 on the real language model

    func testRealAssociationListRespondsToWholePhraseCounts() throws {
        let f = try load()
        let baseline = f.associations.associations(for: "關")
        XCTAssertTrue(baseline.contains("關係"))
        XCTAssertTrue(baseline.contains("關心"))
        XCTAssertEqual(baseline.first, "關係")   // the language model's own order

        // The spec's counts: 關係 8, 關心 3 — 關係 leads, as it already did.
        let counts = ["關係": 8, "關心": 3]
        XCTAssertEqual(f.associations.associations(for: "關") { counts[$0] ?? 0 }.first, "關係")
        // Reverse them and the order follows the counts, not the language model.
        let reversed = ["關係": 3, "關心": 8]
        XCTAssertEqual(f.associations.associations(for: "關") { reversed[$0] ?? 0 }.first, "關心")
        // A count filed under the continuation alone (係) moves nothing: the phrase is the unit.
        XCTAssertEqual(f.associations.associations(for: "關") { $0 == "係" ? 99 : 0 }, baseline)
    }

    // MARK: - A fresh store changes nothing, anywhere (the baseline guarantee)

    func testAFreshStoreLeavesEveryRealListByteForByteUnchanged() throws {
        let f = try load()
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RealAdaptive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fresh = CandidateUsageStore(fileURL: CandidateUsageStore.defaultFileURL(directory: dir))

        // Every 倉頡 code in the shipped 五代 table, ordered against an empty store, must equal
        // the same list ordered with no store at all.
        var codes: [String] = []
        f.cangjie.forEachEntry { code, chars in if chars.count > 1 { codes.append(code) } }
        XCTAssertGreaterThan(codes.count, 1000)
        for code in codes.sorted() {
            let withStore = CangjieEngine(table: f.cangjie, characterRank: f.rank, tableVersion: "5",
                                          usageCount: { fresh.count(of: $1, in: $0) })
            let without = CangjieEngine(table: f.cangjie, characterRank: f.rank, tableVersion: "5")
            for k in code { _ = withStore.handleKey(k) }
            for k in code { _ = without.handleKey(k) }
            XCTAssertEqual(withStore.candidates, without.candidates, "code \(code) reordered")
        }
    }

    func testAFreshStoreLeavesTheRealYahooTableOrderUnchanged() throws {
        let f = try load()
        // 三代 supplies an EMPTY rank, so every candidate is unranked and the table's own line
        // order is what must show — with or without an (empty) usage store.
        var codes: [String] = []
        f.yahoo.forEachEntry { code, chars in if chars.count > 1 { codes.append(code) } }
        XCTAssertGreaterThan(codes.count, 1000)
        for code in codes.sorted().prefix(2000) {
            let e = CangjieEngine(table: f.yahoo, characterRank: [:], tableVersion: "3",
                                  usageCount: { _, _ in 0 })
            for k in code { _ = e.handleKey(k) }
            XCTAssertEqual(e.candidates, f.yahoo.characters(forCode: code), "code \(code) reordered")
        }
    }
}
