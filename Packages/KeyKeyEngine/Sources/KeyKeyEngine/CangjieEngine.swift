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

    // Sort score for a character the language model has no entry for. Shared with SimplexEngine,
    // which ranks the same characters from the same `characterRank` (as it already shares
    // `radicals`), so the two cannot drift apart.
    //
    // It must sit BELOW every real score, so an untrained list is ordered exactly as the dictionary
    // says and unranked characters keep the table's own order behind the ranked ones. Real
    // single-character scores in the bundled model span [-8, 0], so -12 clears that with margin.
    //
    // It must also sit WITHIN REACH of a user-learning bonus, which is the half this got wrong
    // until 2.13.4 (issue #130). The value was -1e9, and the largest bonus UserFrequency can ever
    // produce is log(1 + 100_000) * 20 ≈ 230 — so an unranked character could never overtake a
    // ranked one however many times it was picked. It only reordered among the other unranked
    // characters: 55% of 倉頡 and 53% of 速成 candidate positions could not reach the front at all.
    //
    // -12 is therefore paired with `UserFrequency.weight`, and the pair is what has to hold:
    // `log(2) * weight > 0 - unrankedFloor`, so a SINGLE pick outranks the most common character
    // the model knows. At 20 that is 13.86 against 12. Lowering this constant without raising the
    // weight puts characters back out of reach — that inequality is the thing to preserve, not
    // either number on its own. The zero-bonus order is unaffected either way: it is byte-identical
    // to what -1e9 produced across every runtime code in the shipped tables.
    //
    // Those percentages are over the table as the ENGINE sees it — `CangjieTable.init` drops
    // supplementary-plane and Private Use characters via `isRenderableCJK`, so roughly half the
    // lines in Resources/cangjie.txt never reach a candidate list and must not be counted. An
    // earlier draft of this comment quoted 42%/79% from the raw file and was wrong about both.
    static let unrankedFloor = -12.0

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

    // Combined sort score: dict rank (or `unrankedFloor` for unranked chars, kept below any
    // real LM score) plus the live user-learning bonus. A zero bonus leaves the dict-only
    // ordering unchanged; with no dict rank and no bonus all scores tie, so the stable sort
    // preserves the table's order.
    private static func score(for candidate: String, rank: [Character: Double],
                              userRank: (Character) -> Double) -> Double {
        guard let c = candidate.first else { return -.greatestFiniteMagnitude }
        let base = rank[c] ?? Self.unrankedFloor
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
