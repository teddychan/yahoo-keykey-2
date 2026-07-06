import Foundation

/// Phrase/sentence Pinyin engine. Accumulates typed letters, segments them into
/// syllables, converts to toneless zhuyin readings, and runs the Walker to build
/// an editable list of nodes. A node cursor selects which node the candidate
/// window addresses. Unparsable trailing input is kept as a visible raw tail.
public final class PinyinEngine {
    /// Upper bound on syllables in one composition (keeps the per-keystroke walk cheap).
    public static let maxComposingSyllables = 24

    private let syllableTable: PinyinSyllableTable
    private let index: TonelessLanguageModelIndex
    private let userRank: (Character) -> Double
    private let walker: Walker
    private let segmenter: PinyinSegmenter

    private var raw: String = ""            // all typed letters (+ apostrophes)
    private var nodes: [WalkNode] = []
    private var tail: String = ""
    private var cursor: Int = 0             // index into `nodes`

    public init(syllableTable: PinyinSyllableTable,
                index: TonelessLanguageModelIndex,
                userRank: @escaping (Character) -> Double = { _ in 0 }) {
        self.syllableTable = syllableTable
        self.index = index
        self.userRank = userRank
        self.walker = Walker(index: index)
        self.segmenter = PinyinSegmenter(table: syllableTable)
    }

    // MARK: Input

    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        guard (key.isLetter && key.isASCII) || key == "'" else { return false }
        // Cap: refuse further input once at the syllable limit (swallow the key).
        let seg = segmenter.segment(raw + String(key))
        if seg.syllables.count > Self.maxComposingSyllables { return true }
        raw.append(key)
        rewalk()
        return true
    }

    public func backspace() {
        guard !raw.isEmpty else { return }
        raw.removeLast()
        rewalk()
    }

    // MARK: Cursor + candidates

    /// Candidates for the node under the cursor (empty if there is no node).
    public var candidates: [String] {
        guard cursor >= 0, cursor < nodes.count else { return [] }
        return nodes[cursor].candidates
    }

    public func selectCandidate(_ index: Int) {
        guard cursor >= 0, cursor < nodes.count else { return }
        guard index >= 0, index < nodes[cursor].candidates.count else { return }
        nodes[cursor].chosenIndex = index
    }

    @discardableResult
    public func moveCursorLeft() -> Bool {
        guard cursor > 0 else { return false }
        cursor -= 1; return true
    }

    @discardableResult
    public func moveCursorRight() -> Bool {
        guard cursor < nodes.count - 1 else { return false }
        cursor += 1; return true
    }

    // MARK: Output

    public var composingText: String {
        nodes.map(\.chosenText).joined() + tail
    }

    @discardableResult
    public func commit() -> String {
        let text = composingText
        raw = ""; nodes = []; tail = ""; cursor = 0
        return text
    }

    // MARK: Testing hooks
    public var syllableCountForTesting: Int { nodes.reduce(0) { $0 + $1.readingRange.count } }

    // MARK: Private

    private func rewalk() {
        let seg = segmenter.segment(raw)
        tail = seg.tail
        let readings = seg.syllables.compactMap { syllableTable.zhuyin(forSyllable: $0) }
        nodes = walker.walk(readings: readings, rawSyllables: seg.syllables, userBonus: userRank)
        if cursor >= nodes.count { cursor = max(0, nodes.count - 1) }
    }
}
