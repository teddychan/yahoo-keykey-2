import Foundation

/// 許氏 (Hsu) — the 26-letter 注音 keyboard, where one key stands for several symbols and the
/// symbol is decided by what has been typed around it.
///
/// Unlike 大千 and 倚天, 許氏 is not a key → symbol map: `m` is ㄇ before a vowel and ㄢ after one,
/// `j` is ㄐ, ㄓ or the fourth tone, and so on. So the engine cannot write a key into a slot the
/// moment it arrives; it re-reads the whole key sequence of the syllable instead. This is a port
/// of McBopomofo's `BopomofoKeyboardLayout::syllableFromKeySequence` and its Hsu table
/// (Source/Engine/Mandarin/Mandarin.h and Mandarin.cpp, MIT licence), the same project this app's
/// language model comes from. Only the rules the Hsu keys can reach are carried over.
enum ZhuyinHsu {
    private enum Slot { case consonant, middle, vowel, tone }

    /// One candidate meaning of a key.
    private struct Component: Equatable {
        let symbol: Character
        var slot: Slot {
            if ZhuyinSyllable.initials.contains(symbol) { return .consonant }
            if ZhuyinSyllable.medials.contains(symbol) { return .middle }
            if ZhuyinSyllable.finals.contains(symbol) { return .vowel }
            return .tone
        }
        var isVowel: Bool { slot == .vowel }
        var isTone: Bool { slot == .tone }
        // J, Q, X must be followed by ㄧ or ㄩ; ㄓ ㄔ ㄕ ㄖ ㄗ ㄘ ㄙ never are.
        var isJQX: Bool { "ㄐㄑㄒ".contains(symbol) }
        var isZCSR: Bool { "ㄓㄔㄕㄖㄗㄘㄙ".contains(symbol) }
    }

    // Each key's meanings, most consonant-like first — the order McBopomofo's rules expect.
    private static let table: [Character: [Component]] = {
        let rows: [Character: String] = [
            "b": "ㄅ", "p": "ㄆ", "m": "ㄇㄢ", "f": "ㄈˇ", "d": "ㄉˊ", "t": "ㄊ",
            "n": "ㄋㄣ", "l": "ㄌㄥㄦ", "g": "ㄍㄜ", "k": "ㄎㄤ", "h": "ㄏㄛ",
            "j": "ㄐㄓˋ", "v": "ㄑㄔ", "c": "ㄒㄕ", "r": "ㄖ", "z": "ㄗ",
            "a": "ㄘㄟ", "s": "ㄙ˙", "e": "ㄧㄝ", "x": "ㄨ", "u": "ㄩ",
            "y": "ㄚ", "i": "ㄞ", "w": "ㄠ", "o": "ㄡ",
        ]
        return rows.mapValues { $0.map { Component(symbol: $0) } }
    }()

    // The key a resolved symbol was typed with. Every symbol sits on exactly one key.
    private static let keyForSymbol: [Character: Character] = {
        var map: [Character: Character] = [:]
        for (key, components) in table { for c in components { map[c.symbol] = key } }
        return map
    }()

    private static let toneKeys: Set<Character> = ["d", "f", "j", "s"]

    static func claims(_ key: Character) -> Bool { table[key] != nil }

    /// The syllable after `key` is typed onto `syllable`, or nil when 許氏 does not use the key.
    /// McBopomofo re-resolves "keys of the syllable so far + this key", and so does this.
    static func combine(_ key: Character, into syllable: ZhuyinSyllable) -> ZhuyinSyllable? {
        guard claims(key) else { return nil }
        return resolve(keySequence(of: syllable) + [key])
    }

    /// The syllable with its last typed key taken back off.
    static func removeLastKey(from syllable: ZhuyinSyllable) -> ZhuyinSyllable {
        resolve(Array(keySequence(of: syllable).dropLast()))
    }

    // Consonant, medial, final, tone — each as the key that types it. The first tone is the Space
    // bar, so it has no key and contributes nothing here.
    private static func keySequence(of syllable: ZhuyinSyllable) -> [Character] {
        var symbols: [Character] = []
        if let c = syllable.initial { symbols.append(c) }
        if let m = syllable.medial { symbols.append(m) }
        if let f = syllable.final { symbols.append(f) }
        if let mark = syllable.tone?.mark.first { symbols.append(mark) }
        return symbols.compactMap { keyForSymbol[$0] }
    }

    // A syllable under construction, with McBopomofo's slot masks so its comparisons carry over:
    // consonant 0x1f, middle 0x60, vowel 0x780, tone 0x3800, compared as numbers.
    private struct Draft {
        var consonant: Character?
        var middle: Character?
        var vowel: Character?
        var tone: Character?

        var isEmpty: Bool { consonant == nil && middle == nil && vowel == nil && tone == nil }
        var mask: Int {
            (consonant != nil ? 0x001f : 0) | (middle != nil ? 0x0060 : 0)
                | (vowel != nil ? 0x0780 : 0) | (tone != nil ? 0x3800 : 0)
        }

        static func mask(of c: Component) -> Int {
            switch c.slot {
            case .consonant: return 0x001f
            case .middle: return 0x0060
            case .vowel: return 0x0780
            case .tone: return 0x3800
            }
        }

        mutating func put(_ c: Component) {
            switch c.slot {
            case .consonant: consonant = c.symbol
            case .middle: middle = c.symbol
            case .vowel: vowel = c.symbol
            case .tone: tone = c.symbol
            }
        }
    }

    private static func resolve(_ keys: [Character]) -> ZhuyinSyllable {
        var draft = Draft()
        // ㄧ's and ㄩ's keys: a J/Q/X or ㄝ decision depends on whether either is around.
        let medialKeys: Set<Character> = [keyForSymbol["ㄧ"]!, keyForSymbol["ㄩ"]!]

        for (i, key) in keys.enumerated() {
            guard let components = table[key] else { continue }
            if components.count == 1 { draft.put(components[0]); continue }

            let head = components[0], follow = components[1]
            let ending = components.count > 2 ? components[2] : follow
            let before = keys[..<i].contains { medialKeys.contains($0) }
            let ahead = keys[(i + 1)...].contains { medialKeys.contains($0) }
            let atEndOrBeforeTone = i + 1 == keys.count || toneKeys.contains(keys[i + 1])

            // ㄧ / ㄝ share a key: ㄝ only once a medial has been typed before it.
            if head.symbol != "ㄝ", follow.symbol == "ㄝ" {
                draft.put(before ? follow : head)
                continue
            }

            // ㄐㄑㄒ / ㄓㄔㄕ share keys: ㄐㄑㄒ only when a ㄧ or ㄩ comes after.
            if head.isJQX, !follow.isJQX {
                if !draft.isEmpty {
                    if ending != follow { draft.put(ending) }
                } else {
                    draft.put(ahead ? head : follow)
                }
                continue
            }

            // A lone key: prefer the reading that stands alone as a syllable.
            if i == 0, keys.count == 1 {
                if head.isVowel || follow.isTone || head.isZCSR {
                    draft.put(head)
                } else if follow.isVowel || ending.isTone {
                    draft.put(follow)
                } else {
                    draft.put(ending)
                }
                continue
            }

            if draft.mask & Draft.mask(of: head) == 0, !atEndOrBeforeTone {
                draft.put(head)
            } else if atEndOrBeforeTone, head.isZCSR, draft.isEmpty {
                draft.put(head)
            } else if draft.mask < Draft.mask(of: follow) {
                draft.put(follow)
            } else if draft.mask == Draft.mask(of: follow), draft.mask == 0x0780 {
                draft.put(head)
            } else {
                draft.put(ending)
            }
        }

        // A bare ㄥ is really ㄦ; ㄍ + ㄧ/ㄩ is really ㄐ (ㄍㄧ, ㄍㄩ are not syllables).
        if draft.vowel == "ㄥ", draft.consonant == nil, draft.middle == nil {
            draft.vowel = "ㄦ"
        } else if draft.consonant == "ㄍ", draft.middle == "ㄧ" || draft.middle == "ㄩ" {
            draft.consonant = "ㄐ"
        }

        return ZhuyinSyllable(initial: draft.consonant, medial: draft.middle, final: draft.vowel,
                              tone: draft.tone.flatMap { ZhuyinSyllable.Tone.tone(forMark: $0) })
    }
}
