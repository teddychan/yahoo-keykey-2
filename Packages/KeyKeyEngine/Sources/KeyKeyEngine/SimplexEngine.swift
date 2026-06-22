// Simplex (簡易) engine: accumulate radical letter keys (a–z), look up the matching
// characters in the SimplexTable, then select/commit. Mirrors the CangjieEngine surface
// (handleKey/composingText/candidates/selectCandidate/commit/backspace). Reuses
// CangjieEngine.radicals for the composing-display glyphs.
public final class SimplexEngine {
    private let table: SimplexTable
    private let characterRank: [Character: Double]
    private var code: String = ""
    private var selected: String?

    public init(table: SimplexTable, characterRank: [Character: Double] = [:]) {
        self.table = table
        self.characterRank = characterRank
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
        if characterRank.isEmpty { return matches }
        return matches.enumerated().sorted { lhs, rhs in
            let l = lhs.element.first.flatMap { characterRank[$0] } ?? -.greatestFiniteMagnitude
            let r = rhs.element.first.flatMap { characterRank[$0] } ?? -.greatestFiniteMagnitude
            if l != r { return l > r }
            return lhs.offset < rhs.offset
        }.map(\.element)
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
