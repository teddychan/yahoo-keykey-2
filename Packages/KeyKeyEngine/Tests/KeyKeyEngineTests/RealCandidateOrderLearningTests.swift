import XCTest
import Foundation
@testable import KeyKeyEngine

// Issue #130, against the SHIPPED tables rather than a fixture.
//
// `UnrankedCharacterLearningTests` pins the rule with a three-character table and stays fast.
// This suite pins the case the report was actually about, on the data a user types against: 龍 is
// in the language model, the variant 㡣 is not, they share the 五代 code `ybysp`, and before 2.13.4
// no number of picks could put 㡣 first, and one pick puts it first now. A synthetic table cannot
// catch a regression in the relationship between the real LM's score range and the two constants
// that have to clear it — `CangjieEngine.unrankedFloor` and `UserFrequency.weight` — because the
// fixture chooses both sides of that comparison.
//
// It also guards the measurement, not just the behaviour. The figures quoted in CHANGELOG.md and
// the engines' comments were once taken from raw Resources/cangjie.txt, which overstated them:
// `CangjieTable.init` drops supplementary-plane and Private Use characters through
// `isRenderableCJK` before anything is ranked, so about half the file's lines never reach a
// candidate list. Everything here goes through `CangjieTable`/`SimplexTable` for that reason.
//
// SKIPS when Resources/data.txt is absent, following RealPinyinWalkerTests. That file is generated
// by tools/build-lm.sh and gitignored, and .github/workflows/tests.yml does not build it — so this
// suite skips on CI and runs for whoever has a built tree, which is anyone who can produce a
// release build. It is a pre-release gate, not a CI one; UnrankedCharacterLearningTests is the
// part that always runs.
final class RealCandidateOrderLearningTests: XCTestCase {
    // The pair from the report: same 五代 code, one in the model and one not.
    private static let sharedCode = "ybysp"      // 卜月卜尸心
    private static let ranked: Character = "龍"
    private static let unranked: Character = "㡣"
    // 速成 reduces `ybysp` to first + last radical.
    private static let simplexCode = "yp"

    private var tempDir: URL!
    private var store: UserFrequency!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RealCandidateOrderLearningTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = UserFrequency(fileURL: UserFrequency.defaultFileURL(directory: tempDir))
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func resource(_ rel: String) -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    private struct Fixture {
        let cangjie: CangjieTable
        let simplex: SimplexTable
        let rank: [Character: Double]
    }

    private func loadShippedData() throws -> Fixture {
        guard let tableURL = resource("Resources/cangjie.txt"),
              let dataURL = resource("Resources/data.txt") else {
            throw XCTSkip("Resources/cangjie.txt or Resources/data.txt not present")
        }
        let cangjie = try CangjieTable(contentsOf: tableURL)
        let text = try String(contentsOf: dataURL, encoding: .utf8)
        return Fixture(cangjie: cangjie,
                       simplex: SimplexTable(cangjie: cangjie),
                       rank: LanguageModel.characterScores(fromText: text))
    }

    private func cangjieCandidates(_ f: Fixture) -> [String] {
        let e = CangjieEngine(table: f.cangjie, characterRank: f.rank,
                              userRank: { [store] in store!.bonus(for: $0) })
        for key in Self.sharedCode { _ = e.handleKey(key) }
        return e.candidates
    }

    private func simplexCandidates(_ f: Fixture) -> [String] {
        let e = SimplexEngine(table: f.simplex, characterRank: f.rank,
                              userRank: { [store] in store!.bonus(for: $0) })
        for key in Self.simplexCode { _ = e.handleKey(key) }
        return e.candidates
    }

    // MARK: The premise

    // If this fails, the pair below stopped being an example of the bug and the rest of the suite
    // is testing nothing — the LM was rebuilt, or the table changed, and the cases need rechoosing.
    func testTheReportedPairIsStillOneRankedAndOneUnrankedCharacter() throws {
        let f = try loadShippedData()
        XCTAssertNotNil(f.rank[Self.ranked], "龍 should carry a language-model score")
        XCTAssertNil(f.rank[Self.unranked], "㡣 should be absent from the language model")
        XCTAssertEqual(f.cangjie.characters(matching: Self.sharedCode),
                       [String(Self.ranked), String(Self.unranked)],
                       "ybysp should still offer exactly 龍 then 㡣")
    }

    // MARK: 倉頡

    func testUnrankedVariantOvertakesTheRankedOneInCangjie() throws {
        let f = try loadShippedData()
        // Pick 0 is the dictionary's order. Pick 1 is +13.86 against a gap of 12 - 3.89, so it
        // already leads — and the second pick is asserted too, because "it leads and stays there"
        // is the part a user checks. The pair was the report's own example.
        XCTAssertEqual(cangjieCandidates(f), ["龍", "㡣"], "before any pick")
        store.record(Self.unranked)
        XCTAssertEqual(cangjieCandidates(f), ["㡣", "龍"], "after one pick")
        store.record(Self.unranked)
        XCTAssertEqual(cangjieCandidates(f), ["㡣", "龍"], "after two picks")
    }

    // MARK: 速成

    func testUnrankedVariantClimbsToTheFrontInSimplex() throws {
        let f = try loadShippedData()
        // 速成 is the case the report was about: `yp` is a long list, and before 2.13.4 㡣 moved
        // from position 39 to 36 on its first pick and then never moved again at any count. The
        // starting position is asserted as "not first" rather than as 39, so a table or LM rebuild
        // that shifts the list does not fail a test about learning; the finish is exact, because
        // one pick reaching the front is the promise and there is nothing softer to assert.
        func position() throws -> Int {
            let candidates = simplexCandidates(f)
            let index = try XCTUnwrap(candidates.firstIndex(of: String(Self.unranked)),
                                      "㡣 should be a candidate for the 速成 code yp")
            return index + 1
        }

        XCTAssertGreaterThan(try position(), 1, "㡣 should not already lead the untrained list")
        store.record(Self.unranked)
        XCTAssertEqual(try position(), 1, "㡣 should lead after one pick")
        store.record(Self.unranked)
        XCTAssertEqual(try position(), 1, "㡣 should still lead after a second pick")
    }

    // MARK: The setting, and the store

    func testTurningLearningOffRestoresTheDictionaryOrder() throws {
        let f = try loadShippedData()
        store.record(Self.unranked)
        XCTAssertEqual(cangjieCandidates(f), ["㡣", "龍"], "learning on")

        // What InputController hands the engines when the toggle is off: a zero bonus, not a
        // different engine. The order must be the dictionary's again, immediately.
        let off = CangjieEngine(table: f.cangjie, characterRank: f.rank, userRank: { _ in 0 })
        for key in Self.sharedCode { _ = off.handleKey(key) }
        XCTAssertEqual(off.candidates, ["龍", "㡣"], "learning off")
    }

    func testLearningSurvivesReloadingTheStoreFromDisk() throws {
        let f = try loadShippedData()
        store.record(Self.unranked)
        let bonusBefore = store.bonus(for: Self.unranked)
        XCTAssertGreaterThan(bonusBefore, 0)
        store.flush()

        // A second store over the same file is what the next launch sees. The promotion has to
        // come back with it, or the fix only lasts until the user quits.
        let fileURL = UserFrequency.defaultFileURL(directory: tempDir)
        let reloaded = UserFrequency(fileURL: fileURL)
        XCTAssertEqual(reloaded.bonus(for: Self.unranked), bonusBefore, accuracy: 1e-9)

        let e = CangjieEngine(table: f.cangjie, characterRank: f.rank,
                              userRank: { reloaded.bonus(for: $0) })
        for key in Self.sharedCode { _ = e.handleKey(key) }
        XCTAssertEqual(e.candidates, ["㡣", "龍"], "reloaded counts should still promote 㡣")
    }

    // MARK: The floor's other side

    // The untrained order is the dictionary's across the whole shipped table, not just for the
    // pair above — that is the promise the release note makes to anyone with learning off, and it
    // only holds while the floor is below every real score.
    func testNoRankedCharacterEverSitsBehindAnUnrankedOneWithoutLearning() throws {
        let f = try loadShippedData()
        var checked = 0
        f.cangjie.forEachEntry { _, chars in
            guard chars.count > 1 else { return }
            let e = CangjieEngine(table: CangjieTable(text: chars.map { "zzzzz\t\($0)" }.joined(separator: "\n")),
                                  characterRank: f.rank, userRank: { _ in 0 })
            for key in "zzzzz" { _ = e.handleKey(key) }
            let ranked = e.candidates.map { $0.first.map { f.rank[$0] != nil } ?? false }
            // Once an unranked character appears, no ranked one may follow it.
            if let firstUnranked = ranked.firstIndex(of: false) {
                XCTAssertFalse(ranked[firstUnranked...].contains(true),
                               "a ranked character sorted behind an unranked one: \(e.candidates)")
            }
            checked += 1
        }
        XCTAssertGreaterThan(checked, 1000, "expected many multi-candidate codes in the real table")
    }
}
