// Simplex (簡易) engine: accumulate radical letter keys (a–z), look up the matching
// characters in the SimplexTable, then select/commit. Mirrors the CangjieEngine surface
// (handleKey/composingText/candidates/selectCandidate/commit/backspace). Reuses
// CangjieEngine.radicals for the composing-display glyphs.
public final class SimplexEngine {
    private let table: SimplexTable
    private let characterRank: [Character: Double]
    // Live per-character bonus added on top of the dict rank (user learning). Consulted on
    // every sort, so newly-learned characters promote without rebuilding the engine.
    private let userRank: (Character) -> Double
    private var code: String = ""
    private var selected: String?

    public init(table: SimplexTable, characterRank: [Character: Double] = [:],
                userRank: @escaping (Character) -> Double = { _ in 0 }) {
        self.table = table
        self.characterRank = characterRank
        self.userRank = userRank
    }

    /// Returns true if the key was consumed by the engine. Accepts a–z radical keys.
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        guard CangjieEngine.radicals[key] != nil else { return false }
        code.append(key)
        selected = nil
        return true
    }

    /// Simplex has no tone concept, so it never holds a tone-pending syllable.
    public var isComposingSyllable: Bool { false }

    /// The radical glyphs accumulated so far (selected char once chosen).
    public var composingText: String {
        if let selected { return selected }
        return String(code.map { CangjieEngine.radicals[$0] ?? $0 })
    }

    /// Characters whose Simplex code matches the current radical sequence,
    /// stable-sorted so common characters (higher rank) come first. With an empty
    /// rank the table order is preserved unchanged.
    public var candidates: [String] {
        guard !code.isEmpty else { return [] }
        let matches = table.characters(forCode: code)
        return matches.enumerated().sorted { lhs, rhs in
            let l = Self.score(for: lhs.element, rank: characterRank, userRank: userRank)
            let r = Self.score(for: rhs.element, rank: characterRank, userRank: userRank)
            if l != r { return l > r }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    // Combined sort score: dict rank (or a finite floor for unranked chars, kept below any
    // real LM score) plus the live user-learning bonus. A zero bonus leaves the dict-only
    // ordering unchanged; with no dict rank and no bonus all scores tie, so the stable sort
    // preserves the table's order.
    private static func score(for candidate: String, rank: [Character: Double],
                              userRank: (Character) -> Double) -> Double {
        guard let c = candidate.first else { return -.greatestFiniteMagnitude }
        // Finite floor, far below any real LM score (log-probs ~[-12, 0]) yet leaving
        // headroom for a finite user bonus to lift an otherwise-unranked character.
        let base = rank[c] ?? -1e9
        return base + userRank(c)
    }

    public func selectCandidate(_ index: Int) {
        let cands = candidates
        guard index >= 0, index < cands.count else { return }
        selected = cands[index]
    }

    public func backspace() {
        selected = nil
        if !code.isEmpty { code.removeLast() }
    }

    @discardableResult
    public func commit() -> String {
        let text = selected ?? candidates.first ?? ""
        code = ""
        selected = nil
        return text
    }
}
