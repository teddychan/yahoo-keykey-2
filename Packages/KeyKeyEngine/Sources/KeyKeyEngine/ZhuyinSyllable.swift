import Foundation

/// One 注音 syllable under composition: at most an initial (聲母), a medial (介音), a final
/// (韻母) and a tone (聲調), which is exactly what one Chinese character reads as.
///
/// The four parts are SLOTS, not a list of keystrokes, because that is how 注音 typing works:
/// typing ㄆ after ㄅ corrects the initial rather than appending to it, and the parts always
/// display in their canonical order however they were typed. The engine drives this type; the
/// keyboard layout (ZhuyinKeyboardLayout) has already turned keys into symbols by the time
/// anything here runs.
public struct ZhuyinSyllable: Equatable, Sendable {
    /// The five tones, written as the bundled table writes them: the first tone is UNMARKED and
    /// every other tone is a suffix (ㄋㄧˇ, ㄉㄜ˙). That convention is shared by the ㄅ半 table
    /// and by McBopomofo's language model, so a reading built here is a lookup key in both.
    public enum Tone: Equatable, Sendable, CaseIterable {
        case first, second, third, fourth, neutral

        /// The mark this tone appends to a reading — empty for the first tone.
        public var mark: String {
            switch self {
            case .first: return ""
            case .second: return "ˊ"
            case .third: return "ˇ"
            case .fourth: return "ˋ"
            case .neutral: return "˙"
            }
        }

        /// The tone a mark stands for, or nil when the symbol is not a tone mark. The first tone
        /// has no mark to type — it is the Space bar, which reaches the engine as
        /// `ZhuyinEngine.applyFirstTone()`.
        public static func tone(forMark mark: Character) -> Tone? {
            switch mark {
            case "ˊ": return .second
            case "ˇ": return .third
            case "ˋ": return .fourth
            case "˙": return .neutral
            default: return nil
            }
        }
    }

    public static let initials = Set("ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ")
    public static let medials = Set("ㄧㄨㄩ")
    public static let finals = Set("ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ")

    public private(set) var initial: Character?
    public private(set) var medial: Character?
    public private(set) var final: Character?
    public private(set) var tone: Tone?

    public init() {}

    /// True once a tone has been applied, i.e. the syllable is finished and addresses a candidate
    /// list. 注音 (ㄅ半) shows candidates only at this point — which is also what keeps the number
    /// row usable: on 大千 the tone keys ARE digits, so a candidate window opened before the tone
    /// would swallow them.
    public var isComplete: Bool { tone != nil && hasSymbol }
    /// True once any 注音 symbol has been typed (a tone mark alone is not a syllable).
    public var hasSymbol: Bool { initial != nil || medial != nil || final != nil }
    public var isEmpty: Bool { !hasSymbol && tone == nil }

    /// The reading this spells — initial, medial, final, tone mark — or nil when no symbol has
    /// been typed yet. This is the lookup key into `ZhuyinTable`.
    public var reading: String? {
        guard hasSymbol else { return nil }
        var text = ""
        if let initial { text.append(initial) }
        if let medial { text.append(medial) }
        if let final { text.append(final) }
        text += tone?.mark ?? ""
        return text
    }

    /// What the user sees while composing: the reading, or the empty string when nothing has been
    /// typed. The first tone adds nothing, exactly as it is written everywhere else.
    public var displayText: String { reading ?? "" }

    /// Write one 注音 symbol (or tone mark) into its slot, replacing whatever that slot held.
    /// Returns false for anything that is not a 注音 symbol.
    ///
    /// A symbol typed into an already-complete syllable lands in its slot like any other, which
    /// reads as correcting the initial. It is NOT how a finished syllable is left behind: that is
    /// `ZhuyinEngine.keyStartsNewComposition(_:)`, which the controller checks first so the
    /// character in progress is committed rather than overwritten.
    @discardableResult
    public mutating func insert(_ symbol: Character) -> Bool {
        if let tone = Tone.tone(forMark: symbol) {
            // A tone with nothing to put it on is not a syllable; the engine rejects the key so
            // it can fall through to the app (a 大千 typist's stray `3` should type a 3).
            guard hasSymbol else { return false }
            self.tone = tone
            return true
        }
        if Self.initials.contains(symbol) { initial = symbol; return true }
        if Self.medials.contains(symbol) { medial = symbol; return true }
        if Self.finals.contains(symbol) { final = symbol; return true }
        return false
    }

    /// Apply the first tone — the Space bar on every 注音 keyboard. Returns false when there is
    /// no symbol to tone, so the caller can let Space keep its other meanings.
    @discardableResult
    public mutating func applyFirstTone() -> Bool {
        guard hasSymbol else { return false }
        tone = .first
        return true
    }

    /// Clear the last-written part — tone first, then final, medial, initial. Returns false when
    /// there was nothing to remove.
    @discardableResult
    public mutating func removeLast() -> Bool {
        if tone != nil { tone = nil; return true }
        if final != nil { final = nil; return true }
        if medial != nil { medial = nil; return true }
        if initial != nil { initial = nil; return true }
        return false
    }

    public mutating func clear() { self = ZhuyinSyllable() }
}
