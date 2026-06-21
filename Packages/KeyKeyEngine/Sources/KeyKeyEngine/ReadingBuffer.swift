// Assembles layout components into one Syllable. A tone completes the syllable.
public struct ReadingBuffer {
    public enum Result: Equatable {
        case updated(String)     // syllable changed, not yet complete (BPMF so far)
        case completed(String)   // tone received; finished reading; buffer cleared
        case empty               // nothing to do (e.g. backspace on empty)
        case unhandled           // key not part of the layout
    }

    private let layout: PhoneticLayout
    private var syllable = Syllable()
    // order in which classes were set, to support backspace
    private var order: [Class] = []
    private enum Class { case consonant, medial, vowel, tone }

    public init(layout: PhoneticLayout = StandardLayout()) { self.layout = layout }

    public var isEmpty: Bool { syllable.isEmpty }

    public mutating func receive(_ key: Character) -> Result {
        guard let resolution = layout.resolve(key: key, given: syllable) else { return .unhandled }
        switch resolution {
        case .phoneme(let next):
            syllable = next
            rebuildOrder()
            return .updated(syllable.bpmf)
        case .tone(let t):
            // tone completes only if there is something to commit
            guard !syllable.isEmpty else { return .empty }
            syllable.tone = t
            let reading = syllable.bpmf
            syllable = Syllable(); order = []
            return .completed(reading)
        }
    }

    // Rebuild the backspace order canonically from the resolved syllable. A
    // state-aware keystroke can rewrite an already-set class (e.g. Hsu ㄍ->ㄐ),
    // so the original typing order is not recoverable; canonical order is the
    // faithful minimal choice.
    private mutating func rebuildOrder() {
        order = []
        if syllable.consonant != nil { order.append(.consonant) }
        if syllable.medial != nil { order.append(.medial) }
        if syllable.vowel != nil { order.append(.vowel) }
        if syllable.tone != nil { order.append(.tone) }
    }

    public mutating func backspace() -> Result {
        guard let last = order.popLast() else { return .empty }
        switch last {
        case .consonant: syllable.consonant = nil
        case .medial:    syllable.medial = nil
        case .vowel:     syllable.vowel = nil
        case .tone:      syllable.tone = nil
        }
        return .updated(syllable.bpmf)
    }
}
