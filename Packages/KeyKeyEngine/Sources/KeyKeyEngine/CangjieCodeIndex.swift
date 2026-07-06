import Foundation

// Reverse of `CangjieTable`: maps each character to the 倉頡 code that produces it, so the
// candidate window can show a "拆碼提示 / 反查" hint (e.g. 倉 → 人口竹口). Built once per loaded
// table and rebuilt on a 倉頡版本 change, so the hint always matches the active table.
//
// When a character has several codes we keep the SHORTEST (ties broken lexicographically) —
// that is the canonical decomposition a learner wants to see. Codes are the raw a–z letter
// sequences from the table; `codeGlyphs(for:)` maps each letter to its radical glyph via
// `CangjieEngine.radicals`.
public struct CangjieCodeIndex {
    // char -> its canonical letter code (shortest, lexicographic tie-break).
    private let codeByCharacter: [Character: String]

    public init(table: CangjieTable) {
        var map: [Character: String] = [:]
        table.forEachEntry { code, chars in
            for str in chars {
                guard let ch = str.first, str.count == 1 else { continue }
                if let existing = map[ch] {
                    // Prefer shorter; on equal length prefer lexicographically smaller.
                    if (code.count, code) < (existing.count, existing) { map[ch] = code }
                } else {
                    map[ch] = code
                }
            }
        }
        codeByCharacter = map
    }

    /// The 倉頡 code for `character` rendered as radical glyphs (人口竹口), or `nil` if the
    /// character is not in the table. A letter with no radical mapping (should not occur for
    /// a–z codes) falls back to the letter itself.
    public func codeGlyphs(for character: Character) -> String? {
        guard let code = codeByCharacter[character] else { return nil }
        return String(code.map { CangjieEngine.radicals[$0] ?? $0 })
    }
}
