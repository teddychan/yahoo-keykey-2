// Standard (大千 / Dachen) Bopomofo layout. ASCII key -> phoneme component.
// Source of truth: McBopomofo Mandarin.cpp CreateStandardLayout().
public enum Component: Equatable {
    case consonant(Character)
    case medial(Character)
    case vowel(Character)
    case tone(Character?)   // nil == tone 1 (no mark)
}

// Outcome of resolving one key against the current syllable.
public enum Resolution: Equatable {
    case phoneme(Syllable)    // consonant/medial/vowel update; carries the WHOLE
                              // new syllable (one key may change two classes,
                              // e.g. Hsu ㄍ+ㄧ -> ㄐㄧ). Does not complete.
    case tone(Character?)     // tone received (nil == tone 1, no mark); completes
                              // the reading if the syllable already has content.
}

// A keyboard-to-phoneme mapping. Lets ReadingBuffer stay layout-agnostic.
public protocol PhoneticLayout {
    // Stateless direct map (full-keyboard layouts: Standard, ETen): one key ->
    // one fixed phoneme.
    func component(for key: Character) -> Component?

    // State-aware resolution for 26-key layouts (Hsu, ETen26): the same key
    // resolves to a different phoneme — or to a tone — depending on the syllable
    // typed so far. Returns nil if the key is unmapped. Default impl applies the
    // stateless `component(for:)`, so direct layouts get correct behaviour free.
    func resolve(key: Character, given syllable: Syllable) -> Resolution?
}

public extension PhoneticLayout {
    func resolve(key: Character, given syllable: Syllable) -> Resolution? {
        guard let component = component(for: key) else { return nil }
        var s = syllable
        switch component {
        case .consonant(let c): s.consonant = c
        case .medial(let m):    s.medial = m
        case .vowel(let v):     s.vowel = v
        case .tone(let t):      return .tone(t)
        }
        return .phoneme(s)
    }
}

public struct StandardLayout: PhoneticLayout {
    public init() {}


    private static let consonants: [Character: Character] = [
        "1": "ㄅ", "q": "ㄆ", "a": "ㄇ", "z": "ㄈ",
        "2": "ㄉ", "w": "ㄊ", "s": "ㄋ", "x": "ㄌ",
        "e": "ㄍ", "d": "ㄎ", "c": "ㄏ",
        "r": "ㄐ", "f": "ㄑ", "v": "ㄒ",
        "5": "ㄓ", "t": "ㄔ", "g": "ㄕ", "b": "ㄖ",
        "y": "ㄗ", "h": "ㄘ", "n": "ㄙ",
    ]
    private static let medials: [Character: Character] = [
        "u": "ㄧ", "j": "ㄨ", "m": "ㄩ",
    ]
    private static let vowels: [Character: Character] = [
        "8": "ㄚ", "i": "ㄛ", "k": "ㄜ", ",": "ㄝ",
        "9": "ㄞ", "o": "ㄟ", "l": "ㄠ", ".": "ㄡ",
        "0": "ㄢ", "p": "ㄣ", ";": "ㄤ", "/": "ㄥ",
        "-": "ㄦ",
    ]
    private static let tones: [Character: Character?] = [
        " ": nil, "6": "ˊ", "3": "ˇ", "4": "ˋ", "7": "˙",
    ]

    public static func component(for key: Character) -> Component? {
        if let c = consonants[key] { return .consonant(c) }
        if let m = medials[key] { return .medial(m) }
        if let v = vowels[key] { return .vowel(v) }
        if let t = tones[key] { return .tone(t) }   // value may itself be nil (tone 1)
        return nil
    }

    public func component(for key: Character) -> Component? {
        StandardLayout.component(for: key)
    }
}
