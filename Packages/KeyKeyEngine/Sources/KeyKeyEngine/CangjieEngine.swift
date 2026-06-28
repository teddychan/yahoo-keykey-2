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
    // Live per-character bonus added on top of the dict rank (user learning). Consulted on
    // every sort, so newly-learned characters promote without rebuilding the engine.
    private let userRank: (Character) -> Double
    private var code: String = ""
    private var selected: String?
    // Cached result of the `candidates` computation; invalidated (nil) on any state
    // change to the code. `candidates` is read multiple times per keydown.
    private var cachedCandidates: [String]?

    public init(table: CangjieTable, characterRank: [Character: Double] = [:],
                userRank: @escaping (Character) -> Double = { _ in 0 }) {
        self.table = table
        self.characterRank = characterRank
        self.userRank = userRank
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

    /// Characters whose code matches the current radical sequence (supports `*`),
    /// stable-sorted so common characters (higher rank) come first. With an empty
    /// rank the table order is preserved unchanged.
    public var candidates: [String] {
        if let cachedCandidates { return cachedCandidates }
        let result = computeCandidates()
        cachedCandidates = result
        return result
    }

    private func computeCandidates() -> [String] {
        guard !code.isEmpty else { return [] }
        let matches = table.characters(matching: code)
        // Score each candidate ONCE, then sort the (element, score) pairs.
        return matches.enumerated().map { offset, element in
            (offset, element, Self.score(for: element, rank: characterRank, userRank: userRank))
        }.sorted { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
            return lhs.0 < rhs.0
        }.map(\.1)
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
