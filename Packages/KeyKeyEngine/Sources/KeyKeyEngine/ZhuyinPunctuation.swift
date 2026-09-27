import Foundation

/// The punctuation keys 注音 moves, per layout.
///
/// On 大千 the 注音 symbols ㄝ ㄡ ㄤ ㄥ ㄦ occupy `,` `.` `;` `/` `-`, so the marks those keys
/// carry elsewhere in the app move to their SHIFTED forms: `<` types ，and `>` types 。 — which
/// is not an invention here but the original Yahoo! KeyKey's own arrangement, from the
/// `_punctuation_Standard_*` rows of its `DataTables/bpmf-punctuations.cin`.
///
/// Only the entries that DIFFER from the shared `Punctuation` table are listed. Everything else a
/// 注音 typist presses — `[`  `]`  `!`  `?`  `~`  `` ` ``  and the rest — is already the same mark
/// in both, so it is left to the one table the other input methods use rather than copied into a
/// second one that could drift.
public enum ZhuyinPunctuation {
    // 大千. `'` is not a 大千 key, so its Yahoo! KeyKey mapping (、) applies unshifted, and `"`
    // (its shifted form) carries ；exactly as that table has it.
    private static let dachen: [Character: String] = [
        "<": "，",   // FULLWIDTH COMMA (U+FF0C)        — `,` types ㄝ
        ">": "。",   // IDEOGRAPHIC FULL STOP (U+3002)  — `.` types ㄡ
        "'": "、",   // IDEOGRAPHIC COMMA (U+3001)
        "\"": "；",  // FULLWIDTH SEMICOLON (U+FF1B)    — `;` types ㄤ
    ]

    // 倚天. `,` and `.` type ㄓ and ㄔ here, so the same two shifted keys carry ，。; `'` and `` ` ``
    // are 注音 keys in this layout (ㄘ and nothing), and the engine claims them before punctuation
    // is consulted.
    private static let eten: [Character: String] = [
        "<": "，",
        ">": "。",
    ]

    /// The full-width mark this key types while 注音 is the active method, or nil to fall back to
    /// the shared `Punctuation` table.
    public static func fullWidth(for key: Character,
                                 layout: ZhuyinKeyboardLayout.Identifier) -> String? {
        switch layout {
        case .dachen: return dachen[key]
        case .eten: return eten[key]
        }
    }
}
