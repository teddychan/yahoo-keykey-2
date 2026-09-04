// Simplex (簡易) engine: accumulate radical letter keys (a–z), look up the matching
// characters in the SimplexTable, then select/commit. Mirrors the CangjieEngine surface
// (handleKey/composingText/candidates/selectCandidate/commit/backspace). Reuses
// CangjieEngine.radicals for the composing-display glyphs.
public final class SimplexEngine {
    // A 速成 code is the 倉頡 first + last radical, so it is never longer than two keys —
    // see SimplexTable.simplexCode(for:). Used by keyStartsNewComposition(_:).
    private static let maxRadicals = 2

    private let table: SimplexTable
    private let characterRank: [Character: Double]
    // Which 倉頡 table this 速成 table was derived from ("5"/"3"). Part of the list identity,
    // because the two tables answer the same code with different characters.
    private let tableVersion: String
    // How many times a candidate has been committed in a given list. Consulted on every sort, so
    // a freshly-committed candidate leads next time without rebuilding the engine.
    private let usageCount: (CandidateListKey, String) -> Int
    private var code: String = ""
    private var selected: String?
    // Cached result of the `candidates` computation; invalidated (nil) on any state
    // change to the code. `candidates` is read multiple times per keydown.
    private var cachedCandidates: [String]?

    /// `tableVersion` has no default, for the reason on `CangjieEngine.init`.
    public init(table: SimplexTable, characterRank: [Character: Double] = [:],
                tableVersion: String,
                usageCount: @escaping (CandidateListKey, String) -> Int = { _, _ in 0 }) {
        self.table = table
        self.characterRank = characterRank
        self.tableVersion = tableVersion
        self.usageCount = usageCount
    }

    /// Returns true if the key was consumed by the engine. Accepts a–z radical keys.
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        guard CangjieEngine.radicals[key] != nil else { return false }
        code.append(key)
        selected = nil
        cachedCandidates = nil
        return true
    }

    /// Whether typing `key` now must END this composition and begin a new one (issue #113).
    ///
    /// A 速成 code is two radicals at most, so a further radical key cannot belong to the code
    /// being typed — it is the start of the next character, and the original Yahoo! KeyKey
    /// commits the character in progress and carries on. Appending it instead would build a
    /// 3-key code that no 速成 table contains, leaving a composition with no candidate to pick
    /// and no way out but Backspace.
    ///
    /// The caller (InputController) commits, then feeds the key to `handleKey` on the fresh
    /// composition; false for anything `handleKey` would reject, since there is no key to carry
    /// over. Deliberately not folded into `handleKey`, which cannot commit into the client.
    public func keyStartsNewComposition(_ key: Character) -> Bool {
        code.count >= Self.maxRadicals && CangjieEngine.radicals[key] != nil
    }

    /// The radical glyphs accumulated so far (selected char once chosen).
    public var composingText: String {
        if let selected { return selected }
        return String(code.map { CangjieEngine.radicals[$0] ?? $0 })
    }

    /// Characters whose Simplex code matches the current radical sequence, ordered
    /// frequency-first over the built-in order (see `CandidateOrdering`). With no committed
    /// usage the table/rank order is preserved unchanged.
    public var candidates: [String] {
        if let cachedCandidates { return cachedCandidates }
        let result = computeCandidates()
        cachedCandidates = result
        return result
    }

    private func computeCandidates() -> [String] {
        guard !code.isEmpty, let list = candidateListKey else { return [] }
        let matches = table.characters(forCode: code)
        return CandidateOrdering.ordered(matches, rank: characterRank) { usageCount(list, $0) }
    }

    /// Which candidate list the current code addresses, or nil when nothing is being composed.
    /// 速成 has no wildcard, so this is always the exact code's own list — separate from the
    /// 倉頡 list of the same code, which offers a different set of characters.
    public var candidateListKey: CandidateListKey? {
        code.isEmpty ? nil : .simplex(tableVersion: tableVersion, code: code)
    }

    /// What a commit right now would credit; empty after `commit()` has cleared the code, so a
    /// caller MUST read this first. See `CangjieEngine.pendingUsage`.
    public var pendingUsage: [CandidateUsage] {
        let cands = candidates
        guard cands.count > 1, let list = candidateListKey,
              let candidate = selected ?? cands.first else { return [] }
        return [CandidateUsage(list: list, candidate: candidate)]
    }

    public func selectCandidate(_ index: Int) {
        let cands = candidates
        guard index >= 0, index < cands.count else { return }
        selected = cands[index]
    }

    public func backspace() {
        selected = nil
        if !code.isEmpty { code.removeLast() }
        cachedCandidates = nil
    }

    @discardableResult
    public func commit() -> String {
        let text = selected ?? candidates.first ?? ""
        code = ""
        selected = nil
        cachedCandidates = nil
        return text
    }
}
