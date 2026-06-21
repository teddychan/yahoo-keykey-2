// Assembles layout components into one Syllable. A tone completes the syllable.
public struct ReadingBuffer {
    public enum Result: Equatable {
        case updated(String)     // syllable changed, not yet complete (BPMF so far)
        case completed(String)   // tone received; finished reading; buffer cleared
        case empty               // nothing to do (e.g. backspace on empty)
        case unhandled           // key not part of the layout
    }

    private var syllable = Syllable()
    // order in which classes were set, to support backspace
    private var order: [Class] = []
    private enum Class { case consonant, medial, vowel, tone }

    public init() {}

    public var isEmpty: Bool { syllable.isEmpty }

    public mutating func receive(_ key: Character) -> Result {
        guard let component = StandardLayout.component(for: key) else { return .unhandled }
        switch component {
        case .consonant(let c):
            syllable.consonant = c
            track(.consonant)
        case .medial(let m):
            syllable.medial = m
            track(.medial)
        case .vowel(let v):
            syllable.vowel = v
            track(.vowel)
        case .tone(let t):
            // tone completes only if there is something to commit
            guard !syllable.isEmpty else { return .empty }
            syllable.tone = t
            let reading = syllable.bpmf
            syllable = Syllable(); order = []
            return .completed(reading)
        }
        return .updated(syllable.bpmf)
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

    private mutating func track(_ cls: Class) {
        order.removeAll { $0 == cls }
        order.append(cls)
    }
}
