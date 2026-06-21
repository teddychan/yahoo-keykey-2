// Standard (大千 / Dachen) Bopomofo layout. ASCII key -> phoneme component.
// Source of truth: McBopomofo Mandarin.cpp CreateStandardLayout().
public enum Component: Equatable {
    case consonant(Character)
    case medial(Character)
    case vowel(Character)
    case tone(Character?)   // nil == tone 1 (no mark)
}

public enum StandardLayout {
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
}
