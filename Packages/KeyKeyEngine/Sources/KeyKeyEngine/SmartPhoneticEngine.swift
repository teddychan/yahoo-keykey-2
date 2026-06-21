// Orchestrates the reading buffer and the grid walk. The IMK controller talks only to this.
public final class SmartPhoneticEngine {
    private let lm: LanguageModel
    private let layout: PhoneticLayout
    private var buffer: ReadingBuffer
    private var readings: [String] = []
    // FIX 4: map reading position -> chosen VALUE (not candidate index).
    // This lets overrides survive even when a multi-syllable phrase wins the walk
    // and compresses the walked-segment array below readings.count.
    private var overrides: [Int: String] = [:]
    // nil means "track the last position"; an explicit value is a user-moved cursor.
    private var cursor: Int?

    public init(languageModel: LanguageModel, layout: PhoneticLayout = StandardLayout()) {
        self.lm = languageModel
        self.layout = layout
        self.buffer = ReadingBuffer(layout: layout)
    }

    /// Returns true if the key was consumed by the engine.
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        switch buffer.receive(key) {
        case .completed(let reading):
            readings.append(reading)
            cursor = nil   // a new syllable re-anchors the cursor to the last position
            return true
        case .updated, .empty:
            return true
        case .unhandled:
            return false
        }
    }

    public func backspace() {
        // if mid-syllable, edit the syllable; otherwise drop the last completed reading
        if case .empty = buffer.backspace(), !readings.isEmpty {
            readings.removeLast()
            // readings.count is now the index of the just-removed reading
            overrides.removeValue(forKey: readings.count)
        }
    }

    /// Current selected reading index. Defaults to the last position; clamped to bounds.
    public var cursorPosition: Int {
        guard !readings.isEmpty else { return 0 }
        let last = readings.count - 1
        return min(max(cursor ?? last, 0), last)
    }

    public func moveCursorLeft() {
        guard !readings.isEmpty else { return }
        cursor = max(cursorPosition - 1, 0)
    }

    public func moveCursorRight() {
        guard !readings.isEmpty else { return }
        cursor = min(cursorPosition + 1, readings.count - 1)
    }

    public func selectCandidate(_ index: Int) {
        selectCandidate(at: cursorPosition, index: index)
    }

    public func selectCandidate(at position: Int, index: Int) {
        guard !readings.isEmpty, position >= 0, position < readings.count else { return }
        let cands = candidates(at: position)
        guard index >= 0, index < cands.count else { return }
        overrides[position] = cands[index]
    }

    // FIX 4: build the grid, apply value-keyed overrides via overrideCandidate, then re-walk.
    // This is the McBopomofo-style approach: override at the node level so the Viterbi
    // re-walk respects the selection even when a multi-syllable phrase would otherwise win.
    public var composingText: String {
        guard !readings.isEmpty else { return "" }
        let grid = ReadingGrid(readings: readings, languageModel: lm)
        for (pos, value) in overrides { grid.overrideCandidate(at: pos, to: value) }
        return grid.walk().joined()
    }

    public var candidates: [String] {
        guard !readings.isEmpty else { return [] }
        return candidates(at: cursorPosition)
    }

    public func candidates(at position: Int) -> [String] {
        guard !readings.isEmpty else { return [] }
        let grid = ReadingGrid(readings: readings, languageModel: lm)
        return grid.candidates(at: position)
    }

    @discardableResult
    public func commit() -> String {
        let text = composingText
        readings = []; overrides = [:]; cursor = nil; buffer = ReadingBuffer(layout: layout)
        return text
    }
}
