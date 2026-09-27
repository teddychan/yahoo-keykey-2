import Foundation

/// Where each 注音 symbol sits on the keyboard.
///
/// A layout is nothing but a key → symbol map: it decides which key types ㄅ, and NOTHING about
/// how symbols combine into a syllable (ZhuyinSyllable) or which characters a reading produces
/// (ZhuyinTable). That separation is why the bundled table is keyed by the READING (ㄋㄧˇ) rather
/// than by the keys pressed (`su3` on 大千) — see tools/build-zhuyin-table.py. Adding a layout is
/// one map here plus a `Preferences.zhuyinLayout` case; nothing else in the engine changes.
///
/// The first tone is deliberately absent from every map: on a real 注音 keyboard it is the Space
/// bar, which the IMK controller owns (Space also pages and commits), so it reaches the engine as
/// `ZhuyinEngine.applyFirstTone()` rather than as a mapped key.
public struct ZhuyinKeyboardLayout: Sendable, Equatable {
    /// Stable identifier, also the persisted `Preferences.zhuyinLayout` value.
    public enum Identifier: String, Sendable, CaseIterable {
        case dachen = "dachen"   // 標準 / 大千 — the layout printed on Taiwanese keyboards
        case eten = "eten"       // 倚天
    }

    public let id: Identifier
    private let keyToSymbol: [Character: Character]

    public init(id: Identifier, keyToSymbol: [Character: Character]) {
        self.id = id
        self.keyToSymbol = keyToSymbol
    }

    /// The 注音 symbol (or tone mark) a typed key stands for, or nil when the key is not part of
    /// this layout. Case is the caller's business: an upper-case letter arrives via Shift, which
    /// the controller routes to 臨時英數 long before the engine sees it.
    public func symbol(for key: Character) -> Character? { keyToSymbol[key] }

    /// The layout for a persisted identifier.
    public static func layout(for id: Identifier) -> ZhuyinKeyboardLayout {
        switch id {
        case .dachen: return .dachen
        case .eten: return .eten
        }
    }

    /// 標準 (大千) — the layout the original Yahoo! KeyKey shipped as its default, and the one
    /// printed on Taiwanese keyboards. Transcribed from the `%keyname` section of the ㄅ半 table
    /// this app bundles (DataTables/bpmf-ext.cin), so the key map and the character table come
    /// from the same file and cannot drift apart.
    public static let dachen = ZhuyinKeyboardLayout(id: .dachen, keyToSymbol: [
        "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ",
        "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
        "e": "ㄍ", "d": "ㄎ", "c": "ㄏ",
        "r": "ㄐ", "f": "ㄑ", "v": "ㄒ",
        "5": "ㄓ", "t": "ㄔ", "g": "ㄕ", "b": "ㄖ",
        "y": "ㄗ", "h": "ㄘ", "n": "ㄙ",
        "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
        "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ",
        "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
        "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ", "-": "ㄦ",
        "6": "ˊ", "3": "ˇ", "4": "ˋ", "7": "˙",
    ])

    /// 倚天 — the other layout in common use, where the symbols sit on the letters that spell
    /// their romanization (ㄅ on `b`, ㄆ on `p`) and the tone keys are `1`–`4`. Transcribed from
    /// McBopomofo's `CreateETenLayout()` (Source/Engine/Mandarin/Mandarin.cpp), the same project
    /// this app's language model comes from.
    public static let eten = ZhuyinKeyboardLayout(id: .eten, keyToSymbol: [
        "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ",
        "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ",
        "v": "ㄍ", "k": "ㄎ", "h": "ㄏ",
        "g": "ㄐ", "7": "ㄑ", "c": "ㄒ",
        ",": "ㄓ", ".": "ㄔ", "/": "ㄕ", "j": "ㄖ",
        ";": "ㄗ", "'": "ㄘ", "s": "ㄙ",
        "e": "ㄧ", "x": "ㄨ", "u": "ㄩ",
        "a": "ㄚ", "o": "ㄛ", "r": "ㄜ", "w": "ㄝ",
        "i": "ㄞ", "q": "ㄟ", "z": "ㄠ", "y": "ㄡ",
        "8": "ㄢ", "9": "ㄣ", "0": "ㄤ", "-": "ㄥ", "=": "ㄦ",
        "2": "ˊ", "3": "ˇ", "4": "ˋ", "1": "˙",
    ])
}
