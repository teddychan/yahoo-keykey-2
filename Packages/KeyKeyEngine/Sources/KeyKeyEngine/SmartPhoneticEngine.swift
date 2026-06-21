// Orchestrates the reading buffer and the grid walk. The IMK controller talks only to this.
public final class SmartPhoneticEngine {
    private let lm: LanguageModel
    private var buffer = ReadingBuffer()
    private var readings: [String] = []
    private var overrides: [Int: Int] = [:]   // reading index -> chosen candidate index

    public init(languageModel: LanguageModel) { self.lm = languageModel }

    /// Returns true if the key was consumed by the engine.
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        switch buffer.receive(key) {
        case .completed(let reading):
            readings.append(reading)
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
            overrides.removeValue(forKey: readings.count)
        }
    }

    public func selectCandidate(_ index: Int) {
        guard !readings.isEmpty else { return }
        overrides[readings.count - 1] = index
    }

    public var composingText: String {
        guard !readings.isEmpty else { return "" }
        // honour single-reading overrides; otherwise take the walked best path
        let walked = ReadingGrid(readings: readings, languageModel: lm).walk()
        if overrides.isEmpty { return walked.joined() }
        var out = walked
        for (i, choice) in overrides where i < readings.count {
            let cands = ReadingGrid(readings: [readings[i]], languageModel: lm).candidates(at: 0)
            if choice < cands.count, i < out.count { out[i] = cands[choice] }
        }
        return out.joined()
    }

    public var candidates: [String] {
        guard !readings.isEmpty else { return [] }
        let grid = ReadingGrid(readings: readings, languageModel: lm)
        return grid.candidates(at: readings.count - 1)
    }

    @discardableResult
    public func commit() -> String {
        let text = composingText
        readings = []; overrides = [:]; buffer = ReadingBuffer()
        return text
    }
}
