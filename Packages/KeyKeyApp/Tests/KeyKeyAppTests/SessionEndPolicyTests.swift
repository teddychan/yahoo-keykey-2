import XCTest
@testable import KeyKeyApp

// Locks issue #70: a candidate or 聯想 page left open must not survive the end of the input
// session. Switching app (or input source) while the association window was showing used to
// leave it stranded on screen over the new app, unreachable — nothing dismissed it, because
// InputController never handled the session ending. SessionEndPolicy is the pure decision
// InputController.deactivateServer(_:) consults.
final class SessionEndPolicyTests: XCTestCase {
    func testAssociationsAreDismissedWithoutCommitting() {
        // The reported case: 聯想 suggestions on screen, no composition. They are offers the user
        // never typed, so the session must end by dismissing them — never by inserting text.
        XCTAssertEqual(SessionEndPolicy.action(hasComposition: false, hasAssociations: true),
                       .dismiss)
    }

    func testCompositionIsCommitted() {
        // Half-typed radicals with the candidate window open: commit, exactly as an explicit
        // commitComposition would, so the marked text does not linger either.
        XCTAssertEqual(SessionEndPolicy.action(hasComposition: true, hasAssociations: false),
                       .commit)
    }

    func testCompositionWinsOverAssociations() {
        // Both flags set is not reachable today (committing clears the composition before
        // associations are offered), but a composition is the state carrying user text, so it
        // must take precedence over a dismiss that would silently drop it.
        XCTAssertEqual(SessionEndPolicy.action(hasComposition: true, hasAssociations: true),
                       .commit)
    }

    func testIdleSessionDoesNothing() {
        // Nothing composing and nothing suggested: no state to clear. (deactivateServer still
        // hides the window unconditionally — that safety net is not this decision's job.)
        XCTAssertEqual(SessionEndPolicy.action(hasComposition: false, hasAssociations: false),
                       .idle)
    }
}
