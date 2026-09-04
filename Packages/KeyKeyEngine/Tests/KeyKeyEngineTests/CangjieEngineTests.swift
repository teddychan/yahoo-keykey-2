import XCTest
@testable import KeyKeyEngine

final class CangjieEngineTests: XCTestCase {
    // a=日, b=月, c=金, ... ; codes -> chars from the real Cangjie scheme.
    static let table = CangjieTable(text: """
    a\t日
    a\t曰
    ab\t明
    abc\t冒
    abcde\t韻
    abcdef\t漏
    """)

    private func make() -> CangjieEngine { CangjieEngine(table: Self.table, tableVersion: "5") }

    func testAccumulatesRadicalGlyphs() {
        let e = make()
        XCTAssertTrue(e.handleKey("a"))   // 日
        XCTAssertTrue(e.handleKey("b"))   // 月
        XCTAssertEqual(e.composingText, "日月")
    }

    func testCandidatesForCurrentCode() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertEqual(e.candidates, ["日", "曰"])
        _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["明"])
    }

    func testNoCandidatesWhenEmpty() {
        XCTAssertEqual(make().candidates, [])
    }

    func testSelectCandidateShowsItAsComposing() {
        let e = make()
        _ = e.handleKey("a")
        e.selectCandidate(1)
        XCTAssertEqual(e.composingText, "曰")
    }

    func testSelectOutOfRangeIgnored() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(5)
        XCTAssertEqual(e.composingText, "日月")
    }

    func testCommitReturnsTextAndClears() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.selectCandidate(0)
        XCTAssertEqual(e.commit(), "明")
        XCTAssertEqual(e.composingText, "")
        XCTAssertEqual(e.candidates, [])
    }

    func testCommitWithoutSelectionUsesFirstCandidate() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.commit(), "明")   // first candidate for "ab", not the radicals
        XCTAssertEqual(e.composingText, "")
    }

    func testCommitWithNoMatchEmitsNothing() {
        let e = make()
        _ = e.handleKey("c")   // no code "c" in the fixture
        XCTAssertEqual(e.commit(), "")
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceRemovesLastRadical() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        e.backspace()
        XCTAssertEqual(e.composingText, "日")
        XCTAssertEqual(e.candidates, ["日", "曰"])
    }

    func testBackspaceClearsSelection() {
        let e = make()
        _ = e.handleKey("a")
        e.selectCandidate(1)
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testBackspaceOnEmptyIsSafe() {
        let e = make()
        e.backspace()
        XCTAssertEqual(e.composingText, "")
    }

    func testMaxFiveRadicalsCap() {
        let e = make()
        for k in "abcdef" { XCTAssertTrue(e.handleKey(k)) } // 6th still consumed, not stored
        XCTAssertEqual(e.composingText, "日月金木水")        // only 5 glyphs
        XCTAssertEqual(e.candidates, ["韻"])                 // code is "abcde"
    }

    func testNonLetterIgnored() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertFalse(e.handleKey("1"))
        XCTAssertFalse(e.handleKey(" "))
        XCTAssertFalse(e.handleKey("A"))   // uppercase is not a radical key
        XCTAssertEqual(e.composingText, "日")
    }

    func testWildcardIsConsumedAndShownLiterally() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertTrue(e.handleKey("*"))
        XCTAssertEqual(e.composingText, "日*")   // * rendered literally
    }

    func testWildcardCandidatesMatchPattern() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("*")
        // "a*" matches "ab","abc","abcde","abcdef" (≥1 letter after a)
        XCTAssertEqual(e.candidates, ["明", "冒", "韻", "漏"])
    }

    func testWildcardBetweenLiterals() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("*"); _ = e.handleKey("b")
        // "a*b" matches codes starting a, ending b, ≥1 between: "ab" is too short? ab=a,b no middle
        XCTAssertEqual(e.candidates, [])
    }

    func testWildcardCountsTowardMaxLength() {
        let e = make()
        for _ in 0..<6 { _ = e.handleKey("*") }
        XCTAssertEqual(e.composingText, "*****")   // capped at 5
    }

    func testWildcardCandidatesRerankedByCharacterRank() {
        // Rank a normally-late char (漏) highest so it leads the "a*" list.
        let rank: [Character: Double] = ["漏": 0.0, "韻": -1.0]
        let e = CangjieEngine(table: Self.table, characterRank: rank, tableVersion: "5")
        _ = e.handleKey("a"); _ = e.handleKey("*")
        // Default table order is ["明","冒","韻","漏"]; ranked chars move ahead
        // (漏 > 韻), unranked ("明","冒") keep their relative order after.
        XCTAssertEqual(e.candidates, ["漏", "韻", "明", "冒"])
    }

    func testEmptyRankLeavesOrderUnchanged() {
        let e = CangjieEngine(table: Self.table, characterRank: [:], tableVersion: "5")
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["明", "冒", "韻", "漏"])
    }

    // MARK: adaptive ordering (issue #130)

    func testOneCommittedCandidateLeadsEveryUnusedOne() {
        // No dict rank, so every candidate starts level: one commit of the last one leads.
        let e = CangjieEngine(table: Self.table, tableVersion: "5",
                              usageCount: { _, c in c == "漏" ? 1 : 0 })
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["漏", "明", "冒", "韻"])
    }

    func testZeroCountsLeaveTheBuiltInOrderUnchanged() {
        // A fresh store answers zero for everything and must not perturb the ranked order.
        let rank: [Character: Double] = ["漏": 0.0, "韻": -1.0]
        let e = CangjieEngine(table: Self.table, characterRank: rank, tableVersion: "5",
                              usageCount: { _, _ in 0 })
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["漏", "韻", "明", "冒"])
    }

    func testACountBeatsAHigherDictionaryRank() {
        // The count decides on its own — it is not added to the dictionary rank — so a single
        // commit of the lower-ranked 漏 puts it ahead of the higher-ranked 韻.
        let rank: [Character: Double] = ["韻": 1.0, "漏": 0.0]
        let e = CangjieEngine(table: Self.table, characterRank: rank, tableVersion: "5",
                              usageCount: { _, c in c == "漏" ? 1 : 0 })
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["漏", "韻", "明", "冒"])
    }

    func testHigherCountLeadsLowerCount() {
        let counts = ["韻": 2, "漏": 5]
        let e = CangjieEngine(table: Self.table, tableVersion: "5",
                              usageCount: { _, c in counts[c] ?? 0 })
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["漏", "韻", "明", "冒"])
    }

    func testEqualCountsKeepTheBuiltInOrder() {
        // Everything committed the same number of times: the table order stands. Which one was
        // committed most recently is not part of the ordering and cannot change this.
        let e = CangjieEngine(table: Self.table, tableVersion: "5", usageCount: { _, _ in 4 })
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.candidates, ["明", "冒", "韻", "漏"])
    }

    func testExactCodeAndWildcardAreSeparateLists() {
        // The engine asks about the pattern as typed, so `a*` usage cannot be answered from the
        // exact code `a` — and both keys carry the table version.
        var asked: [CandidateListKey] = []
        let e = CangjieEngine(table: Self.table, tableVersion: "3",
                              usageCount: { list, _ in asked.append(list); return 0 })
        _ = e.handleKey("a")
        _ = e.candidates
        XCTAssertEqual(e.candidateListKey, .cangjie(tableVersion: "3", code: "a"))
        _ = e.handleKey("*")
        _ = e.candidates
        XCTAssertEqual(e.candidateListKey, .cangjieWildcard(tableVersion: "3", pattern: "a*"))
        XCTAssertTrue(asked.contains(.cangjie(tableVersion: "3", code: "a")))
        XCTAssertTrue(asked.contains(.cangjieWildcard(tableVersion: "3", pattern: "a*")))
        XCTAssertFalse(asked.contains(.cangjie(tableVersion: "5", code: "a")))
    }

    func testPendingUsageNamesTheCommittedCandidateAndIsGoneAfterCommit() {
        let e = CangjieEngine(table: Self.table, tableVersion: "5")
        _ = e.handleKey("a"); _ = e.handleKey("*")
        e.selectCandidate(2)   // 韻
        XCTAssertEqual(e.pendingUsage,
                       [CandidateUsage(list: .cangjieWildcard(tableVersion: "5", pattern: "a*"),
                                       candidate: "韻")])
        XCTAssertEqual(e.commit(), "韻")
        // The code is cleared by commit, so the list identity is gone: it MUST be read first.
        XCTAssertEqual(e.pendingUsage, [])
        XCTAssertNil(e.candidateListKey)
    }

    func testPendingUsageDefaultsToTheFirstCandidateForSpaceAndReturn() {
        // Space/Return select the first candidate of the page before committing; with nothing
        // selected at all the engine still commits the first candidate, and credits that one.
        let e = CangjieEngine(table: Self.table, tableVersion: "5")
        _ = e.handleKey("a"); _ = e.handleKey("*")
        XCTAssertEqual(e.pendingUsage.first?.candidate, "明")
    }

    func testPendingUsageIsEmptyForASingleCandidateList() {
        // "ab" resolves to one character: nothing to reorder, so nothing worth counting.
        let e = CangjieEngine(table: Self.table, tableVersion: "5")
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.candidates.count, 1)
        XCTAssertEqual(e.pendingUsage, [])
    }

    func testCandidatesCacheInvalidatedByBackspace() {
        // candidates is cached; mutating the code (backspace) must refresh it.
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["明"])   // "ab" -> caches
        e.backspace()
        XCTAssertEqual(e.candidates, ["日", "曰"])   // now "a", cache refreshed
    }

    func testCandidatesCacheInvalidatedByHandleKey() {
        let e = make()
        _ = e.handleKey("a")
        XCTAssertEqual(e.candidates, ["日", "曰"])   // caches for "a"
        _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["明"])   // appending "b" refreshes the cache
    }

    func testCandidatesCacheInvalidatedByCommit() {
        let e = make()
        _ = e.handleKey("a"); _ = e.handleKey("b")
        XCTAssertEqual(e.candidates, ["明"])
        _ = e.commit()
        XCTAssertEqual(e.candidates, [])   // committed -> empty code, cache cleared
    }

    func testRadicalMapCoversFullAlphabet() {
        for k in "abcdefghijklmnopqrstuvwxyz" {
            XCTAssertNotNil(CangjieEngine.radicals[k], "missing radical for \(k)")
        }
        XCTAssertEqual(CangjieEngine.radicals.count, 26)
    }
}
