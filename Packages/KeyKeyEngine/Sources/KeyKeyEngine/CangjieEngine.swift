// Cangjie (倉頡) engine: accumulate up to 5 radical letter keys (a–z), look up the
// matching characters in the table, then select/commit. Exposes the engine
// surface (handleKey/composingText/candidates/selectCandidate/commit/backspace).
public final class CangjieEngine {
    // a–z -> the 倉頡 radical glyph it represents, for the composing display.
    public static let radicals: [Character: Character] = [
        "a": "日", "b": "月", "c": "金", "d": "木", "e": "水", "f": "火",
        "g": "土", "h": "竹", "i": "戈", "j": "十", "k": "大", "l": "中",
        "m": "一", "n": "弓", "o": "人", "p": "心", "q": "手", "r": "口",
        "s": "尸", "t": "廿", "u": "山", "v": "女", "w": "田", "x": "難",
        "y": "卜", "z": "重",
    ]

    private static let maxRadicals = 5

    private let table: CangjieTable
    private let characterRank: [Character: Double]
    // Which 倉頡 table these candidates come from ("5"/"3"). Part of every list identity this
    // engine reports, because 三代 and 五代 answer the same code with different characters — the
    // same code is a different candidate list in each, and their counts must not mix.
    private let tableVersion: String
    // How many times a candidate has been committed in a given list. Consulted on every sort, so
    // a freshly-committed candidate leads next time without rebuilding the engine.
    private let usageCount: (CandidateListKey, String) -> Int
    private var code: String = ""
    private var selected: String?
    // Cached result of the `candidates` computation; invalidated (nil) on any state
    // change to the code. `candidates` is read multiple times per keydown.
    private var cachedCandidates: [String]?

    /// `tableVersion` has no default on purpose: a defaulted one would let a call site put
    /// 三代 and 五代 counts in the same list by omitting an argument. `usageCount` does default,
    /// to the no-learning answer — zero everywhere leaves the built-in order untouched.
    public init(table: CangjieTable, characterRank: [Character: Double] = [:],
                tableVersion: String,
                usageCount: @escaping (CandidateListKey, String) -> Int = { _, _ in 0 }) {
        self.table = table
        self.characterRank = characterRank
        self.tableVersion = tableVersion
        self.usageCount = usageCount
    }

    /// Returns true if the key was consumed by the engine.
    /// Accepts a–z radical keys and `*` (wildcard for one-or-more unknown radicals).
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        guard Self.radicals[key] != nil || key == "*" else { return false }
        guard code.count < Self.maxRadicals else { return true }
        code.append(key)
        selected = nil
        cachedCandidates = nil
        return true
    }

    /// The 倉頡 radical glyphs accumulated so far, e.g. "日月". `*` is shown literally.
    public var composingText: String {
        if let selected { return selected }
        return String(code.map { Self.radicals[$0] ?? $0 })
    }

    /// Characters whose code matches the current radical sequence (supports `*`), ordered
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
        let matches = table.characters(matching: code)
        return CandidateOrdering.ordered(matches, rank: characterRank) { usageCount(list, $0) }
    }

    /// Which candidate list the current code addresses, or nil when nothing is being composed.
    ///
    /// A code carrying `*` is its OWN list, keyed by the pattern as typed: `h*i` matches a
    /// different set of characters than the exact code `hi` does, and than `h*e` does, so usage
    /// under one must not move the others.
    public var candidateListKey: CandidateListKey? {
        guard !code.isEmpty else { return nil }
        return code.contains("*")
            ? .cangjieWildcard(tableVersion: tableVersion, pattern: code)
            : .cangjie(tableVersion: tableVersion, code: code)
    }

    /// What a commit right now would credit: the candidate `commit()` is about to return, in the
    /// list it is being picked from. Empty once `commit()` has run, because the code that
    /// identifies the list is gone by then — so a caller MUST read this before committing.
    ///
    /// Empty too for a single-candidate list: with nothing to reorder there is no order to learn,
    /// and counting it would fill the store with records that can never change an outcome.
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
