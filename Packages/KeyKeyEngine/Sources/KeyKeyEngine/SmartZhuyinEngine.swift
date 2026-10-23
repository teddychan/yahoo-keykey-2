import Foundation

/// One stretch of the marked text, so the controller can underline the character the cursor is on.
public struct ComposingSegment: Equatable {
    public let text: String
    public let isCursor: Bool
    public init(text: String, isCursor: Bool) { self.text = text; self.isCursor = isCursor }
}

/// 智慧注音: type a whole sentence of 注音 and let the language model pick the characters.
///
/// The classic Yahoo! KeyKey 好打注音 behaviour, as opposed to the one-character-at-a-time ㄅ半
/// (`ZhuyinEngine`). Keys go through the same keyboard layout as ㄅ半 — including 許氏, whose keys
/// need a syllable's neighbours to be read — and a tone (or Space, the first tone) ends each
/// syllable. The finished readings are walked as a whole, so 你好 comes out from `ㄋㄧˇ ㄏㄠˇ`
/// without choosing either character.
///
/// The cursor sits on a SYLLABLE, not on a word: the model may have joined 太長 into one word, but
/// the cursor can still stop on 長 and offer 常. What the candidate list offers there, in order:
/// the choices for the word the walk currently uses, then every single character for that
/// syllable, then longer words that run through it. Picking one pins that stretch of the sentence
/// and the model walks the rest around it.
public final class SmartZhuyinEngine {
    /// Upper bound on syllables in one composition (keeps the per-keystroke walk cheap).
    public static let maxComposingSyllables = 24
    private static let maxCandidates = 120

    /// A candidate: `value` written over the syllables in `range`.
    private struct Pick: Equatable {
        let range: Range<Int>
        let value: String
    }

    private let layout: ZhuyinKeyboardLayout
    private let index: TonelessLanguageModelIndex
    private let walker: Walker
    private let userRank: (Character) -> Double
    private let usageCount: (CandidateListKey, String) -> Int

    private var finished: [ZhuyinSyllable] = []   // syllables a tone has ended
    private var current = ZhuyinSyllable()        // the syllable being typed
    private var overrides: [Pick] = []            // stretches the user has pinned
    private var nodes: [WalkNode] = []
    private var cursor = 0                        // index of a finished syllable
    private var cachedPicks: [Pick]?
    // True once the user has moved the cursor off the end to revisit a character. Only then is a
    // character marked: while typing at the end the cursor is the end, and marking is noise.
    private var browsing = false
    // True while the last finished syllable is the one just completed, with nothing typed since.
    // Only that one is taken back into 注音 by Backspace; the ones before it are deleted whole.
    private var freshTail = false

    /// `index` must be built with `keepTones: true`: its keys are full readings (ㄋㄧˇ-ㄏㄠˇ).
    public init(index: TonelessLanguageModelIndex, layout: ZhuyinKeyboardLayout,
                userRank: @escaping (Character) -> Double = { _ in 0 },
                usageCount: @escaping (CandidateListKey, String) -> Int = { _, _ in 0 }) {
        self.layout = layout
        self.index = index
        self.walker = Walker(index: index)
        self.userRank = userRank
        self.usageCount = usageCount
    }

    // MARK: Input

    @discardableResult
    public func handleKey(_ key: Character) -> Bool {
        guard let next = layout.combine(key, into: current) else { return false }
        browsing = false
        freshTail = false
        // A syllable past the cap is refused, but the key is still ours: it must not leak to the app.
        if finished.count >= Self.maxComposingSyllables, next.isComplete { return true }
        current = next
        endSyllableIfComplete()
        return true
    }

    /// Whether `key` is a 注音 key on the active layout. The controller asks before treating a
    /// digit as a candidate pick or a punctuation key as punctuation.
    public func mapsKey(_ key: Character) -> Bool { layout.claims(key) }

    /// The Space bar is the first tone — it finishes a syllable that has symbols but no tone.
    /// False when there is nothing to finish, leaving Space to commit the sentence.
    @discardableResult
    public func applyFirstTone() -> Bool {
        guard !current.isComplete, current.applyFirstTone() else { return false }
        browsing = false
        if finished.count >= Self.maxComposingSyllables { current.clear(); return true }
        endSyllableIfComplete()
        return true
    }

    /// Takes back the last thing typed. The character just finished goes back into 注音 with its
    /// tone off, so a wrong tone is one key to fix; after that, and for every character before it,
    /// Backspace deletes the whole character — walking back through each one's 注音 would take
    /// several keys apiece for something already settled.
    public func backspace() {
        browsing = false
        if current.isEmpty {
            guard let last = finished.popLast() else { return }
            if freshTail { current = layout.backspaced(last) }
            freshTail = false
        } else {
            current = layout.backspaced(current)
        }
        cursor = Int.max
        rewalk()
    }

    // MARK: Cursor + candidates

    /// Candidates for the syllable under the cursor (empty if there is none).
    public var candidates: [String] { picks.map(\.value) }

    /// The 注音 reading of the syllable under the cursor, or nil.
    public var cursorReading: String? {
        guard cursor >= 0, cursor < finished.count else { return nil }
        return finished[cursor].reading
    }

    public func selectCandidate(_ index: Int) {
        let all = picks
        guard index >= 0, index < all.count else { return }
        let pick = all[index]
        // The new stretch replaces any earlier pin it overlaps.
        overrides.removeAll { $0.range.overlaps(pick.range) }
        overrides.append(pick)
        // Rest on the stretch's last syllable, so moving right goes on to what follows it.
        cursor = pick.range.upperBound - 1
        rewalk()
    }

    @discardableResult
    public func moveCursorLeft() -> Bool {
        guard cursor > 0 else { return false }
        cursor -= 1
        browsing = true
        cachedPicks = nil
        return true
    }

    @discardableResult
    public func moveCursorRight() -> Bool {
        guard cursor < finished.count - 1 else { return false }
        cursor += 1
        browsing = true
        cachedPicks = nil
        return true
    }

    // MARK: Output

    /// The sentence so far, then the 注音 of the syllable still being typed.
    public var composingText: String {
        nodes.map(\.chosenText).joined() + current.displayText
    }

    /// The marked text split up, with the character under the cursor flagged once the user has
    /// moved back onto it. The last segment is the unfinished syllable, if any.
    public var segments: [ComposingSegment] {
        var result: [ComposingSegment] = []
        for node in nodes {
            let text = node.chosenText
            guard browsing, node.readingRange.contains(cursor) else {
                result.append(ComposingSegment(text: text, isCursor: false))
                continue
            }
            let chars = Array(text)
            let offset = cursor - node.readingRange.lowerBound
            if node.readingRange.count > 1, chars.count == node.readingRange.count {
                // One character per syllable: mark just the one the cursor is on.
                if offset > 0 { result.append(ComposingSegment(text: String(chars[..<offset]), isCursor: false)) }
                result.append(ComposingSegment(text: String(chars[offset]), isCursor: true))
                if offset + 1 < chars.count {
                    result.append(ComposingSegment(text: String(chars[(offset + 1)...]), isCursor: false))
                }
            } else {
                result.append(ComposingSegment(text: text, isCursor: true))
            }
        }
        if !current.isEmpty { result.append(ComposingSegment(text: current.displayText, isCursor: false)) }
        return result
    }

    /// What a commit right now would credit: every word of the sentence, in the list for its
    /// reading — the one the user picked by hand AND the one they simply accepted. Counting only
    /// hand picks made the character the user keeps taking as the default (是) fall behind one they
    /// had to pick (氏) a few times, which is backwards. A reading with a single choice has no list
    /// to reorder and credits nothing.
    public var pendingUsage: [CandidateUsage] {
        let readings = finishedReadings
        return nodes.compactMap { node in
            guard node.readingRange.upperBound <= readings.count else { return nil }
            let key = readings[node.readingRange].joined(separator: "-")
            guard index.unigrams(forKey: key).count > 1 else { return nil }
            return CandidateUsage(list: .zhuyin(reading: key), candidate: node.chosenText)
        }
    }

    @discardableResult
    public func commit() -> String {
        let text = composingText
        finished = []; current = ZhuyinSyllable(); overrides = []; nodes = []
        cursor = 0; browsing = false; freshTail = false; cachedPicks = nil
        return text
    }

    // MARK: Private

    private var finishedReadings: [String] { finished.compactMap(\.reading) }

    private func endSyllableIfComplete() {
        if current.isComplete {
            finished.append(current)
            current = ZhuyinSyllable()
            freshTail = true
        }
        // Typing always goes on at the end of the sentence.
        cursor = Int.max
        rewalk()
    }

    // The candidate list for the syllable under the cursor, in the order described on the type.
    private var picks: [Pick] {
        if let cachedPicks { return cachedPicks }
        let built = buildPicks()
        cachedPicks = built
        return built
    }

    private func buildPicks() -> [Pick] {
        let readings = finishedReadings
        let n = readings.count
        guard cursor >= 0, cursor < n else { return [] }
        var result: [Pick] = []
        func add(_ pick: Pick) {
            if result.count < Self.maxCandidates, !result.contains(pick) { result.append(pick) }
        }
        func values(over range: Range<Int>) -> [String] {
            let key = readings[range].joined(separator: "-")
            let list = CandidateListKey.zhuyin(reading: key)
            return index.unigrams(forKey: key).map { gram in
                (gram, usageCount(list, gram.value))
            }.sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                let l = lhs.0.score + (lhs.0.value.first.map(userRank) ?? 0)
                let r = rhs.0.score + (rhs.0.value.first.map(userRank) ?? 0)
                return l != r ? l > r : lhs.0.value < rhs.0.value
            }.map { $0.0.value }
        }

        // 1. The word the walk uses at the cursor: picking its first entry changes nothing.
        if let node = nodes.first(where: { $0.readingRange.contains(cursor) }) {
            if overrides.contains(where: { $0.range == node.readingRange }) {
                add(Pick(range: node.readingRange, value: node.chosenText))
            }
            for value in node.candidates { add(Pick(range: node.readingRange, value: value)) }
        }
        // 2. Every single character for this syllable, so a word can be corrected one character at a time.
        let here = cursor..<(cursor + 1)
        let singles = values(over: here)
        if singles.isEmpty { add(Pick(range: here, value: readings[cursor])) }
        for value in singles { add(Pick(range: here, value: value)) }
        // 3. Longer words through this syllable, shortest first.
        if n > 1 {
            for length in 2...min(index.maxSpanLength, n) {
                for start in max(0, cursor - length + 1)...min(cursor, n - length) {
                    let range = start..<(start + length)
                    for value in values(over: range) { add(Pick(range: range, value: value)) }
                }
            }
        }
        return result
    }

    private func rewalk() {
        let readings = finishedReadings
        overrides.removeAll { $0.range.upperBound > readings.count }
        nodes = buildNodes(readings: readings)
        cursor = min(max(0, cursor), max(0, readings.count - 1))
        cachedPicks = nil
    }

    // The sentence as nodes: pinned stretches stay as they are, and the model walks what lies
    // between them.
    private func buildNodes(readings: [String]) -> [WalkNode] {
        var result: [WalkNode] = []
        var position = 0
        func walkFree(_ range: Range<Int>) {
            guard !range.isEmpty else { return }
            let slice = Array(readings[range])
            for node in walker.walk(readings: slice, rawSyllables: slice, userBonus: userRank) {
                let shifted = (node.readingRange.lowerBound + range.lowerBound)
                    ..< (node.readingRange.upperBound + range.lowerBound)
                // What the user has picked before leads, as it does everywhere else.
                let list = CandidateListKey.zhuyin(reading: readings[shifted].joined(separator: "-"))
                let ordered = CandidateOrdering.ordered(node.candidates, rank: [:]) { usageCount(list, $0) }
                result.append(WalkNode(readingRange: shifted, candidates: ordered))
            }
        }
        for pin in overrides.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            walkFree(position..<pin.range.lowerBound)
            result.append(WalkNode(readingRange: pin.range, candidates: [pin.value]))
            position = pin.range.upperBound
        }
        walkFree(position..<readings.count)
        return result
    }
}
