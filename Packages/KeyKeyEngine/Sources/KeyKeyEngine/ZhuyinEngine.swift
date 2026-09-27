import Foundation

/// 注音 (ㄅ半) engine: build ONE syllable from 注音 keys, end it with a tone, pick a character.
///
/// "ㄅ半" is the classic, non-predictive phonetic method — one character at a time, chosen from
/// the list its reading opens — so this engine has the same shape as the 倉頡/速成 ones
/// (handleKey / composingText / candidates / selectCandidate / commit / backspace) rather than
/// the multi-node buffer 拼音 uses. 聯想字詞 follows a commit exactly as it does for 倉頡/速成,
/// which is how a ㄅ半 typist gets whole words without a sentence engine.
///
/// Two rules are the controller's, not this type's, because they need to commit into the client:
/// the Space bar is the first-tone key (`applyFirstTone()`), and a 注音 key typed against a
/// finished syllable starts the next character (`keyStartsNewComposition(_:)`).
public final class ZhuyinEngine {
    private let table: ZhuyinTable
    private let layout: ZhuyinKeyboardLayout
    // How many times a candidate has been committed in a given list. Consulted on every sort, so
    // a freshly-committed candidate leads next time without rebuilding the engine.
    private let usageCount: (CandidateListKey, String) -> Int
    private var syllable = ZhuyinSyllable()
    private var selected: String?
    // Cached result of the `candidates` computation; invalidated (nil) on any state change to the
    // syllable. `candidates` is read several times per keydown.
    private var cachedCandidates: [String]?

    public init(table: ZhuyinTable, layout: ZhuyinKeyboardLayout,
                usageCount: @escaping (CandidateListKey, String) -> Int = { _, _ in 0 }) {
        self.table = table
        self.layout = layout
        self.usageCount = usageCount
    }

    // MARK: Input

    /// Returns true if the key was consumed. A key this layout does not map is not ours — it falls
    /// through to punctuation or to the app.
    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        guard let symbol = layout.symbol(for: key), syllable.insert(symbol) else { return false }
        invalidate()
        return true
    }

    /// Whether this key is a 注音 symbol in the active layout. The controller asks before turning
    /// a key into full-width punctuation, because on 大千 the symbols ㄝ ㄡ ㄤ ㄥ ㄦ sit on
    /// `,` `.` `;` `/` `-` — keys the punctuation table also claims. 注音 wins while 注音 is the
    /// active method, which is what McBopomofo does too; the punctuation those keys would have
    /// typed is on their shifted forms (see ZhuyinPunctuation).
    public func mapsKey(_ key: Character) -> Bool { layout.symbol(for: key) != nil }

    /// The Space bar is the first-tone key on every 注音 keyboard — it is not in any layout map
    /// because Space also pages and commits, which only the controller can do. Returns false when
    /// there is no un-toned syllable to finish, leaving Space its other meanings.
    @discardableResult
    public func applyFirstTone() -> Bool {
        guard !syllable.isComplete, syllable.applyFirstTone() else { return false }
        invalidate()
        return true
    }

    /// Whether typing `key` now must END this syllable and begin the next one.
    ///
    /// A finished syllable — one carrying a tone — is a whole character waiting to be picked, so a
    /// further 注音 key belongs to the next character, not this one. The original ㄅ半 commits the
    /// character in progress and carries straight on, which is what lets a typist run without
    /// pressing Enter between characters. Mirrors `SimplexEngine.keyStartsNewComposition(_:)`,
    /// including why it is not folded into `handleKey`: only the controller can commit into the
    /// client. It then feeds the key to `handleKey` on the fresh syllable.
    public func keyStartsNewComposition(_ key: Character) -> Bool {
        guard syllable.isComplete, let symbol = layout.symbol(for: key) else { return false }
        // A tone key is a correction to the syllable just finished, not the start of the next one.
        return ZhuyinSyllable.Tone.tone(forMark: symbol) == nil
    }

    public func backspace() {
        selected = nil
        _ = syllable.removeLast()
        cachedCandidates = nil
    }

    // MARK: Output

    /// The 注音 typed so far (ㄋㄧˇ), or the character once one has been selected.
    public var composingText: String {
        if let selected { return selected }
        return syllable.displayText
    }

    /// The characters for the finished reading, ordered by how often each has been committed in
    /// THIS reading's list over the table's own order (see `CandidateOrdering`). Empty until a
    /// tone finishes the syllable — which is also what keeps the number row free for typing the
    /// tone: on 大千 the tone keys are digits, and digits pick candidates once the window is up.
    public var candidates: [String] {
        if let cachedCandidates { return cachedCandidates }
        let result = computeCandidates()
        cachedCandidates = result
        return result
    }

    private func computeCandidates() -> [String] {
        guard let list = candidateListKey, let reading = syllable.reading else { return [] }
        // No language-model rank: the bundled ㄅ半 table's own order is the built-in candidate
        // order, the way 三代倉頡's is for 倉頡 — it already leads with the everyday character for
        // a reading (ㄍㄨㄛˊ → 國, ㄉㄜ˙ → 的), and a global per-character ranking would answer a
        // 破音字 reading with the character's commonest OTHER reading. Learning applies on top.
        let matches = table.characters(forReading: reading)
        return CandidateOrdering.ordered(matches, rank: [:]) { usageCount(list, $0) }
    }

    /// Which candidate list the current syllable addresses, or nil while it is unfinished.
    public var candidateListKey: CandidateListKey? {
        guard syllable.isComplete, let reading = syllable.reading else { return nil }
        return .zhuyin(reading: reading)
    }

    /// What a commit right now would credit: the candidate `commit()` is about to return, in the
    /// list it is being picked from. Empty once `commit()` has run, and empty for a
    /// single-candidate list — see `CangjieEngine.pendingUsage`, which this mirrors.
    public var pendingUsage: [CandidateUsage] {
        let cands = candidates
        guard cands.count > 1, let list = candidateListKey,
              let candidate = selected ?? cands.first else { return [] }
        return [CandidateUsage(list: list, candidate: candidate)]
    }

    public func selectCandidate(_ index: Int) {
        let cands = candidates
        guard index >= 0, index < cands.count else { return }
        selected = cands[index]
    }

    @discardableResult
    public func commit() -> String {
        let text = selected ?? candidates.first ?? ""
        syllable.clear()
        selected = nil
        cachedCandidates = nil
        return text
    }

    private func invalidate() {
        selected = nil
        cachedCandidates = nil
    }
}
