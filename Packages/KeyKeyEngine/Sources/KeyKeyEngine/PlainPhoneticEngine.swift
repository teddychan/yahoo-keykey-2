// Classic per-syllable Bopomofo (注音) mode: type ONE syllable, then pick a
// character from that syllable's candidate list. No multi-syllable phrase
// prediction, no grid/Viterbi, no cursor. The IMK controller talks only to this.
public final class PlainPhoneticEngine {
    private let lm: LanguageModel
    private let layout: PhoneticLayout
    private var buffer: ReadingBuffer
    // The completed reading awaiting candidate selection; empty while mid-syllable.
    private var completedReading: String = ""
    // The in-progress BPMF reading while the syllable is still being assembled.
    private var pendingBPMF: String = ""

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
            completedReading = reading
            pendingBPMF = ""
            return true
        case .updated(let bpmf):
            pendingBPMF = bpmf
            return true
        case .empty:
            return true
        case .unhandled:
            return false
        }
    }

    /// True while a phonetic syllable has phonemes typed but no tone applied yet.
    public var isComposingSyllable: Bool { !pendingBPMF.isEmpty }

    /// Mid-syllable: the in-progress BPMF. Otherwise: the completed reading awaiting selection.
    public var composingText: String {
        pendingBPMF.isEmpty ? completedReading : pendingBPMF
    }

    /// For a completed reading, the LM unigrams sorted by score (best first); empty while mid-syllable.
    public var candidates: [String] {
        guard !completedReading.isEmpty else { return [] }
        return lm.unigrams(forKey: completedReading)
            .sorted { $0.score > $1.score }
            .map { $0.value }
    }

    /// Choosing a candidate commits THAT single character and clears the reading.
    @discardableResult
    public func selectCandidate(_ index: Int) -> String {
        let cands = candidates
        guard index >= 0, index < cands.count else { return "" }   // out-of-range is a no-op
        let value = cands[index]
        reset()
        return value
    }

    /// Commits the current best candidate (or the raw reading if none) and clears.
    @discardableResult
    public func commit() -> String {
        let text = candidates.first ?? completedReading
        reset()
        return text
    }

    /// Remove the last component of the in-progress syllable, or clear a completed-but-unselected reading.
    public func backspace() {
        if !completedReading.isEmpty {
            completedReading = ""
            return
        }
        if case .updated(let bpmf) = buffer.backspace() {
            pendingBPMF = bpmf
        }
    }

    private func reset() {
        completedReading = ""
        pendingBPMF = ""
        buffer = ReadingBuffer(layout: layout)
    }
}
