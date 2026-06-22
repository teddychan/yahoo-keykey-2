// Cangjie (倉頡) engine: accumulate up to 5 radical letter keys (a–z), look up the
// matching characters in the table, then select/commit. Mirrors the SmartPhoneticEngine
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
    private var code: String = ""
    private var selected: String?

    public init(table: CangjieTable, characterRank: [Character: Double] = [:]) {
        self.table = table
        self.characterRank = characterRank
    }

    /// Returns true if the key was consumed by the engine.
    /// Accepts a–z radical keys and `*` (wildcard for one-or-more unknown radicals).
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        guard Self.radicals[key] != nil || key == "*" else { return false }
        guard code.count < Self.maxRadicals else { return true }
        code.append(key)
        selected = nil
        return true
    }

    /// Cangjie has no tone concept, so it never holds a tone-pending syllable.
    public var isComposingSyllable: Bool { false }

    /// The 倉頡 radical glyphs accumulated so far, e.g. "日月". `*` is shown literally.
    public var composingText: String {
        if let selected { return selected }
        return String(code.map { Self.radicals[$0] ?? $0 })
    }

    /// Characters whose code matches the current radical sequence (supports `*`),
    /// stable-sorted so common characters (higher rank) come first. With an empty
    /// rank the table order is preserved unchanged.
    public var candidates: [String] {
        guard !code.isEmpty else { return [] }
        let matches = table.characters(matching: code)
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
