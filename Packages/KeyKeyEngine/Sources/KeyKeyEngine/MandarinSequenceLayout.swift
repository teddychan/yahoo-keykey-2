// 26-key Bopomofo layouts (Hsu 許氏, ETen26 倚天26鍵) where a single key resolves
// to different phonemes — or to a tone — depending on the syllable typed so far.
//
// Source of truth: McBopomofo Mandarin (repo openvanilla/McBopomofo,
// Source/Engine/Mandarin/Mandarin.h + Mandarin.cpp):
//   - key -> [component] vectors: CreateHsuLayout() / CreateETen26Layout()
//   - state-dependent disambiguation: BopomofoKeyboardLayout::
//     syllableFromKeySequence() (+ keySequenceFromSyllable round-trip) and the
//     Hsu fixups at the tail of that function.
//
// We reproduce McBopomofo's exact model: a keystroke serialises the current
// syllable back to keys, appends the new key, then RE-PARSES the whole sequence
// into a fresh syllable. The parser below is a direct port of
// syllableFromKeySequence, operating on our internal BPMF component model.

// One BPMF phoneme component, mirroring McBopomofo's bit-masked BopomofoSyllable.
// We keep the same numeric values so the mask/class predicates port verbatim.
internal enum BPMF: UInt16 {
    // ConsonantMask 0x001f
    case B = 0x0001, P = 0x0002, M = 0x0003, F = 0x0004, D = 0x0005, T = 0x0006
    case N = 0x0007, L = 0x0008, G = 0x0009, K = 0x000a, H = 0x000b, J = 0x000c
    case Q = 0x000d, X = 0x000e, ZH = 0x000f, CH = 0x0010, SH = 0x0011, R = 0x0012
    case Z = 0x0013, C = 0x0014, S = 0x0015
    // MiddleVowelMask 0x0060
    case I = 0x0020, U = 0x0040, UE = 0x0060
    // VowelMask 0x0780
    case A = 0x0080, O = 0x0100, ER = 0x0180, E = 0x0200, AI = 0x0280, EI = 0x0300
    case AO = 0x0380, OU = 0x0400, AN = 0x0480, EN = 0x0500, ANG = 0x0580
    case ENG = 0x0600, ERR = 0x0680
    // ToneMarkerMask 0x3800 (Tone1 == 0, i.e. no mark)
    case Tone2 = 0x0800, Tone3 = 0x1000, Tone4 = 0x1800, Tone5 = 0x2000

    static let consonantMask: UInt16 = 0x001f
    static let middleVowelMask: UInt16 = 0x0060
    static let vowelMask: UInt16 = 0x0780
    static let toneMarkerMask: UInt16 = 0x3800

    var maskClass: UInt16 {
        let v = rawValue
        if v & BPMF.consonantMask != 0 { return BPMF.consonantMask }
        if v & BPMF.middleVowelMask != 0 { return BPMF.middleVowelMask }
        if v & BPMF.vowelMask != 0 { return BPMF.vowelMask }
        return BPMF.toneMarkerMask // includes Tone1 (0) only nominally; unused there
    }
}

// A syllable as a bit-set of at most one component per class, mirroring
// BopomofoSyllable. We accumulate via `add` (== McBopomofo operator+=).
private struct BPMFSyllable {
    var bits: UInt16 = 0

    var isEmpty: Bool { bits == 0 }
    var consonant: UInt16 { bits & BPMF.consonantMask }
    var middleVowel: UInt16 { bits & BPMF.middleVowelMask }
    var vowel: UInt16 { bits & BPMF.vowelMask }
    var tone: UInt16 { bits & BPMF.toneMarkerMask }

    var hasConsonant: Bool { consonant != 0 }
    var hasMiddleVowel: Bool { middleVowel != 0 }
    var hasVowel: Bool { vowel != 0 }
    var hasToneMarker: Bool { tone != 0 }

    // The set of class-masks currently occupied (BopomofoSyllable::maskType).
    var maskType: UInt16 {
        var m: UInt16 = 0
        if hasConsonant { m |= BPMF.consonantMask }
        if hasMiddleVowel { m |= BPMF.middleVowelMask }
        if hasVowel { m |= BPMF.vowelMask }
        if hasToneMarker { m |= BPMF.toneMarkerMask }
        return m
    }

    // J/Q/X consonants require an I or UE medial (belongsToJQXClass).
    var belongsToJQXClass: Bool {
        let c = consonant
        return c == BPMF.J.rawValue || c == BPMF.Q.rawValue || c == BPMF.X.rawValue
    }
    // ZH..S consonants (zi ci si zhi chi shi ri) — belongsToZCSRClass.
    var belongsToZCSRClass: Bool {
        let c = consonant
        return c >= BPMF.ZH.rawValue && c <= BPMF.S.rawValue
    }

    mutating func add(_ comp: BPMF) {
        let v = comp.rawValue
        for mask in [BPMF.consonantMask, BPMF.middleVowelMask, BPMF.vowelMask, BPMF.toneMarkerMask] where v & mask != 0 {
            bits = (bits & ~mask) | (v & mask)
        }
    }
}

// Renders BPMF components to Bopomofo characters (componentToCharacter).
private let bpmfToChar: [BPMF: Character] = [
    .B: "ㄅ", .P: "ㄆ", .M: "ㄇ", .F: "ㄈ", .D: "ㄉ", .T: "ㄊ", .N: "ㄋ", .L: "ㄌ",
    .G: "ㄍ", .K: "ㄎ", .H: "ㄏ", .J: "ㄐ", .Q: "ㄑ", .X: "ㄒ", .ZH: "ㄓ", .CH: "ㄔ",
    .SH: "ㄕ", .R: "ㄖ", .Z: "ㄗ", .C: "ㄘ", .S: "ㄙ",
    .I: "ㄧ", .U: "ㄨ", .UE: "ㄩ",
    .A: "ㄚ", .O: "ㄛ", .ER: "ㄜ", .E: "ㄝ", .AI: "ㄞ", .EI: "ㄟ", .AO: "ㄠ", .OU: "ㄡ",
    .AN: "ㄢ", .EN: "ㄣ", .ANG: "ㄤ", .ENG: "ㄥ", .ERR: "ㄦ",
    .Tone2: "ˊ", .Tone3: "ˇ", .Tone4: "ˋ", .Tone5: "˙",
]
private let charToBPMF: [Character: BPMF] = Dictionary(
    uniqueKeysWithValues: bpmfToChar.map { ($0.value, $0.key) })

// Shared engine for the 26-key layouts. Holds the key->[component] map and the
// keySequenceFromSyllable / syllableFromKeySequence round-trip.
internal struct MandarinSequenceLayout {
    let keyToComponents: [Character: [BPMF]]
    let isHsu: Bool
    private let componentToKey: [BPMF: Character]

    init(keyToComponents: [Character: [BPMF]], isHsu: Bool) {
        self.keyToComponents = keyToComponents
        self.isHsu = isHsu
        // First component listed for a value wins as its canonical key
        // (BopomofoKeyboardLayout ctor builds componentToKey_ this way; later
        // duplicates overwrite, but the keys we serialise are unambiguous).
        var c2k: [BPMF: Character] = [:]
        for (key, comps) in keyToComponents {
            for comp in comps { c2k[comp] = key }
        }
        self.componentToKey = c2k
    }

    // Public entry: resolve appending `key` onto the (rendered) prior syllable.
    // Returns a Resolution (.tone if the key produced a tone marker, else
    // .phoneme with the whole new syllable), or nil if the key is unmapped.
    func resolve(key: Character, given prior: Syllable) -> Resolution? {
        guard keyToComponents[key] != nil else { return nil }
        let sequence = keySequence(from: prior) + String(key)
        let parsed = syllable(from: sequence)
        let rendered = render(parsed)
        // If the re-parse yields a tone marker, the key was a tone. (These
        // layouts have no Tone1 key, so the mark is always non-nil. The new key
        // is appended last, so a tone marker here always comes from this key.)
        if parsed.hasToneMarker {
            return .tone(rendered.tone)
        }
        return .phoneme(rendered)
    }

    func isValidKey(_ key: Character) -> Bool { keyToComponents[key] != nil }

    // keySequenceFromSyllable: serialise in canonical class order.
    private func keySequence(from syllable: Syllable) -> String {
        var seq = ""
        func appendKey(_ ch: Character?) {
            guard let ch, let comp = charToBPMF[ch], let k = componentToKey[comp] else { return }
            seq.append(k)
        }
        appendKey(syllable.consonant)
        appendKey(syllable.medial)
        appendKey(syllable.vowel)
        appendKey(syllable.tone)
        return seq
    }

    private func render(_ s: BPMFSyllable) -> Syllable {
        var out = Syllable()
        if s.hasConsonant, let comp = BPMF(rawValue: s.consonant) { out.consonant = bpmfToChar[comp] }
        if s.hasMiddleVowel, let comp = BPMF(rawValue: s.middleVowel) { out.medial = bpmfToChar[comp] }
        if s.hasVowel, let comp = BPMF(rawValue: s.vowel) { out.vowel = bpmfToChar[comp] }
        if s.hasToneMarker, let comp = BPMF(rawValue: s.tone) { out.tone = bpmfToChar[comp] }
        return out
    }

    // The I / UE medial keys, used for look-behind / look-ahead context.
    private var iKey: Character? { componentToKey[.I] }
    private var ueKey: Character? { componentToKey[.UE] }

    private func sequenceContainsIorUE(_ chars: ArraySlice<Character>) -> Bool {
        chars.contains { $0 == iKey || $0 == ueKey }
    }

    private func endAheadOrAheadHasToneMarkKey(_ ahead: ArraySlice<Character>) -> Bool {
        guard let first = ahead.first else { return true } // ahead == end
        let toneKeys: [Character?] = [
            componentToKey[.Tone2], componentToKey[.Tone3],
            componentToKey[.Tone4], componentToKey[.Tone5],
        ]
        return toneKeys.contains { $0 != nil && $0 == first }
        // Note: Tone1 has no key in these layouts (componentToKey[.Tone1] absent).
    }

    // Direct port of BopomofoKeyboardLayout::syllableFromKeySequence.
    private func syllable(from sequence: String) -> BPMFSyllable {
        var syllable = BPMFSyllable()
        let chars = Array(sequence)

        for i in chars.indices {
            let before = chars[chars.startIndex..<i]
            let ahead = chars[(i + 1)..<chars.endIndex]
            let beforeSeqHasIorUE = sequenceContainsIorUE(before)
            let aheadSeqHasIorUE = sequenceContainsIorUE(ahead)

            let components = keyToComponents[chars[i]] ?? []
            if components.isEmpty { continue }
            if components.count == 1 {
                syllable.add(components[0])
                continue
            }

            let head = components[0]
            let follow = components[1]
            let ending = components.count > 2 ? components[2] : follow

            let headVowel = head.rawValue & BPMF.vowelMask
            let followVowel = follow.rawValue & BPMF.vowelMask
            let eVowel = BPMF.E.rawValue

            // I/UE + E rule
            if headVowel == eVowel && followVowel != eVowel {
                syllable.add(beforeSeqHasIorUE ? head : follow)
                continue
            }
            if headVowel != eVowel && followVowel == eVowel {
                syllable.add(beforeSeqHasIorUE ? follow : head)
                continue
            }

            // J/Q/X + I/UE rule (two components only)
            let headJQX = isJQX(head)
            let followJQX = isJQX(follow)
            if headJQX && !followJQX {
                if !syllable.isEmpty {
                    // C++ parity: add `ending` only if it differs from `follow`;
                    // for a 2-component key ending == follow, so this is a
                    // deliberate no-op (the key is dropped, e.g. lone JQX after
                    // an existing syllable that already has its slots).
                    if ending != follow { syllable.add(ending) }
                } else {
                    syllable.add(aheadSeqHasIorUE ? head : follow)
                }
                continue
            }
            if !headJQX && followJQX {
                if !syllable.isEmpty {
                    // C++ parity: add `ending` only if it differs from `follow`;
                    // for a 2-component key ending == follow, so this is a
                    // deliberate no-op (the key is dropped, e.g. lone JQX after
                    // an existing syllable that already has its slots).
                    if ending != follow { syllable.add(ending) }
                } else {
                    syllable.add(aheadSeqHasIorUE ? follow : head)
                }
                continue
            }

            // single char in buffer
            if i == chars.startIndex && i + 1 == chars.endIndex {
                if hasVowel(head) || hasToneMarker(follow) || isZCSR(head) {
                    syllable.add(head)
                } else if hasVowel(follow) || hasToneMarker(ending) {
                    syllable.add(follow)
                } else {
                    syllable.add(ending)
                }
                continue
            }

            let headMask = maskClass(head)
            if (syllable.maskType & headMask) == 0 && !endAheadOrAheadHasToneMarkKey(ahead) {
                syllable.add(head)
            } else {
                if endAheadOrAheadHasToneMarkKey(ahead) && isZCSR(head) && syllable.isEmpty {
                    syllable.add(head)
                } else if syllable.maskType < maskClass(follow) {
                    syllable.add(follow)
                } else {
                    syllable.add(ending)
                }
            }
        }

        // Hsu fixups
        if isHsu {
            if syllable.vowel == BPMF.ENG.rawValue && !syllable.hasConsonant && !syllable.hasMiddleVowel {
                syllable.add(.ERR)
            } else if syllable.consonant == BPMF.G.rawValue
                && (syllable.middleVowel == BPMF.I.rawValue || syllable.middleVowel == BPMF.UE.rawValue) {
                syllable.add(.J)
            }
        }

        return syllable
    }

    // Predicates on a single component (a BopomofoSyllable holding just it).
    private func isJQX(_ c: BPMF) -> Bool {
        c == .J || c == .Q || c == .X
    }
    private func isZCSR(_ c: BPMF) -> Bool {
        let v = c.rawValue & BPMF.consonantMask
        return v >= BPMF.ZH.rawValue && v <= BPMF.S.rawValue
    }
    private func hasVowel(_ c: BPMF) -> Bool { (c.rawValue & BPMF.vowelMask) != 0 }
    private func hasToneMarker(_ c: BPMF) -> Bool { (c.rawValue & BPMF.toneMarkerMask) != 0 }
    private func maskClass(_ c: BPMF) -> UInt16 { c.maskClass }
}

// MARK: - Hsu (許氏)

public struct HsuLayout: PhoneticLayout {
    public init() {}

    private static let engine = MandarinSequenceLayout(keyToComponents: [
        "b": [.B], "p": [.P], "m": [.M, .AN], "f": [.F, .Tone3],
        "d": [.D, .Tone2], "t": [.T], "n": [.N, .EN], "l": [.L, .ENG, .ERR],
        "g": [.G, .ER], "k": [.K, .ANG], "h": [.H, .O],
        "j": [.J, .ZH, .Tone4], "v": [.Q, .CH], "c": [.X, .SH], "r": [.R],
        "z": [.Z], "a": [.C, .EI], "s": [.S, .Tone5], "e": [.I, .E],
        "x": [.U], "u": [.UE], "y": [.A], "i": [.AI], "w": [.AO], "o": [.OU],
    ], isHsu: true)

    // Hsu has no stateless map; resolution is always state-aware.
    public func component(for key: Character) -> Component? { nil }

    public func resolve(key: Character, given syllable: Syllable) -> Resolution? {
        HsuLayout.engine.resolve(key: key, given: syllable)
    }
}

// MARK: - ETen26 (倚天26鍵)

public struct Eten26Layout: PhoneticLayout {
    public init() {}

    private static let engine = MandarinSequenceLayout(keyToComponents: [
        "b": [.B], "p": [.P, .OU], "m": [.M, .AN], "f": [.F, .Tone2],
        "d": [.D, .Tone5], "t": [.T, .ANG], "n": [.N, .EN], "l": [.L, .ENG],
        "v": [.G, .Q], "k": [.K, .Tone4], "h": [.H, .ERR],
        "g": [.ZH, .J], "c": [.SH, .X], "y": [.CH], "j": [.R, .Tone3],
        "q": [.Z, .EI], "w": [.C, .E], "s": [.S], "e": [.I], "x": [.U],
        "u": [.UE], "a": [.A], "o": [.O], "r": [.ER], "i": [.AI], "z": [.AO],
    ], isHsu: false)

    public func component(for key: Character) -> Component? { nil }

    public func resolve(key: Character, given syllable: Syllable) -> Resolution? {
        Eten26Layout.engine.resolve(key: key, given: syllable)
    }
}
