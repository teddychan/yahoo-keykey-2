import XCTest
import Foundation
@testable import KeyKeyEngine

// Issue #130: a character the bundled language model has no entry for must reach the front of the
// candidate list on the FIRST pick. It could not before 2.13.4 — CangjieEngine and SimplexEngine
// floored an unranked character at -1e9, while the largest bonus UserFrequency can ever produce is
// log(1 + 100_000) * 20 ≈ 230, so no number of picks closed the gap. The character climbed past the
// other unranked candidates and then stopped there permanently, which is what the reporter
// described as moving "extremely slowly" and then not at all.
//
// These cases drive a REAL UserFrequency instead of a hand-written bonus closure, which is the
// point of the file: neither side was wrong on its own. The engines were self-consistent, the
// store was self-consistent, and only the two together showed that the bonus scale could not reach
// the floor. A test that invents its own bonus numbers restates that assumption rather than
// checking it, and CangjieEngineTests/SimplexEngineTests (which pass a closure) already cover
// everything that does not depend on the real scale.
//
// One pick, not "a few", is the assertion on purpose. The fix has two halves that only work as a
// pair — the floor `CangjieEngine.unrankedFloor` moved into reach, and `UserFrequency.weight` grew
// to 20 so that `log(2) * weight` clears the whole 12-point span in one step. Asserting a handful
// of picks would pass with either half alone and hide the half that is missing; asserting one pick
// against a character scored 0, the best score the model gives out, IS the inequality.
//
// The cost is deliberate and is written in the release notes: a stray commit now reorders the list
// too, and is undone by picking the character you meant once.
final class UnrankedCharacterLearningTests: XCTestCase {
    // The most common character the model knows scores 0; the rarest it knows scores -8. Both
    // appear here because the two ends bound what learning has to climb past.
    private static let commonScore = 0.0
    private static let rareScore = -8.0

    private var tempDir: URL!
    private var store: UserFrequency!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("UnrankedCharacterLearningTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = UserFrequency(fileURL: UserFrequency.defaultFileURL(directory: tempDir))
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Code "ab" carries 明 (in the model) followed by 昌 and 曇 (not in it) — the mix 41% of
    // multi-candidate 五代 codes have.
    private static let cangjieTable = CangjieTable(text: """
    ab\t明
    ab\t昌
    ab\t曇
    """)

    // The same three characters reached the 速成 way: the code is the first + last radical, so all
    // three of "ab", "amb" and "azb" reduce to "ab".
    private static let simplexTable = SimplexTable(cangjie: CangjieTable(text: """
    ab\t明
    amb\t昌
    azb\t曇
    """))

    private func cangjie(rank: [Character: Double]) -> CangjieEngine {
        let e = CangjieEngine(table: Self.cangjieTable, characterRank: rank,
                              userRank: { [store] in store!.bonus(for: $0) })
        _ = e.handleKey("a"); _ = e.handleKey("b")
        return e
    }

    private func simplex(rank: [Character: Double]) -> SimplexEngine {
        let e = SimplexEngine(table: Self.simplexTable, characterRank: rank,
                              userRank: { [store] in store!.bonus(for: $0) })
        _ = e.handleKey("a"); _ = e.handleKey("b")
        return e
    }

    // MARK: One pick wins

    func testPickingAnUnrankedCangjieCharacterBringsItToTheFront() {
        let rank: [Character: Double] = ["明": Self.commonScore]
        XCTAssertEqual(cangjie(rank: rank).candidates.first, "明", "untrained list should start ranked")

        store.record("昌")
        XCTAssertEqual(cangjie(rank: rank).candidates.first, "昌",
                       "one pick must put an unranked character ahead of the model's most common one")
    }

    func testPickingAnUnrankedSimplexCharacterBringsItToTheFront() {
        // 速成 is where this bit hardest: a multi-candidate two-key code averages ~46 candidates
        // with a median of 20 ranked ones, so a picked variant climbed past the unranked ones
        // above it and then stalled behind the ranked block. RealCandidateOrderLearningTests
        // walks the actual 速成 list this fixture stands in for.
        let rank: [Character: Double] = ["明": Self.commonScore]
        XCTAssertEqual(simplex(rank: rank).candidates.first, "明", "untrained list should start ranked")

        store.record("昌")
        XCTAssertEqual(simplex(rank: rank).candidates.first, "昌",
                       "one pick must put an unranked character ahead of the model's most common one")
    }

    // MARK: The untrained order is the dictionary's

    func testWithoutLearningEvenTheModelsRarestCharacterOutranksAnUnrankedOne() {
        // The floor has to clear the whole model range, not just its middle: 明 scored at the
        // model's worst still leads, and the two unranked characters keep the table's order.
        XCTAssertEqual(cangjie(rank: ["明": Self.rareScore]).candidates, ["明", "昌", "曇"])
        XCTAssertEqual(simplex(rank: ["明": Self.rareScore]).candidates, ["明", "昌", "曇"])
    }

    // MARK: 三代 (no ranking at all) is unaffected

    func testWithAnEmptyRankTheTableOrderStandsUntilSomethingIsPicked() {
        // 三代 passes an empty rank, so every character sits on the floor and learning alone
        // separates them — one pick is enough, exactly as before this change.
        XCTAssertEqual(cangjie(rank: [:]).candidates, ["明", "昌", "曇"])
        store.record("曇")
        XCTAssertEqual(cangjie(rank: [:]).candidates, ["曇", "明", "昌"])
    }
}
