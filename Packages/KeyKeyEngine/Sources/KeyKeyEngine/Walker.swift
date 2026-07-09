import Foundation

/// One node of a walk: a contiguous run of readings and the ordered candidates
/// for that run. `chosenIndex` selects which candidate is committed/shown.
public struct WalkNode: Equatable {
    public let readingRange: Range<Int>
    public let candidates: [String]
    public var chosenIndex: Int
    public init(readingRange: Range<Int>, candidates: [String], chosenIndex: Int = 0) {
        self.readingRange = readingRange
        self.candidates = candidates
        self.chosenIndex = chosenIndex
    }
    public var chosenText: String {
        guard chosenIndex >= 0, chosenIndex < candidates.count else { return candidates.first ?? "" }
        return candidates[chosenIndex]
    }
}

/// Best-path walk over a sequence of toneless zhuyin readings, using unigram
/// scores from a TonelessLanguageModelIndex. Maximizes the summed unigram
/// log-prob (longer/higher-scored phrases win). Bounded so per-keystroke cost
/// stays linear: spans never exceed `maxSpanLength`, and callers cap the reading
/// count (PinyinEngine.maxComposingSyllables).
public struct Walker {
    private let index: TonelessLanguageModelIndex
    private let maxSpan: Int
    /// Score for a raw-text fallback node — below any real log-prob, so the walk
    /// only uses it when nothing better spans that reading.
    private static let rawFallbackScore = -30.0

    public init(index: TonelessLanguageModelIndex) {
        self.index = index
        self.maxSpan = max(1, index.maxSpanLength)
    }

    public func walk(readings: [String], rawSyllables: [String],
                     userBonus: (Character) -> Double) -> [WalkNode] {
        let n = readings.count
        guard n > 0 else { return [] }
        precondition(rawSyllables.count == n, "readings and rawSyllables must align")

        // How the winning span at a boundary is rebuilt into a node, deferred until backtracking
        // so the (userBonus) candidate sort runs only for the ~n chosen spans, not every span the
        // DP evaluates.
        enum SpanChoice {
            case fallback(range: Range<Int>, raw: String)
            case phrase(range: Range<Int>, unigrams: [Unigram])
        }

        // DP over prefix boundaries: best[j] = best total score covering readings[0..<j].
        var best = [Double](repeating: -.greatestFiniteMagnitude, count: n + 1)
        var back = [SpanChoice?](repeating: nil, count: n + 1)
        var prev = [Int](repeating: 0, count: n + 1)
        best[0] = 0

        for j in 1...n {
            let maxL = min(maxSpan, j)
            for L in 1...maxL {
                let i = j - L
                if best[i] == -.greatestFiniteMagnitude { continue }
                let key = readings[i..<j].joined(separator: "-")
                let unis = index.unigrams(forKey: key)
                let spanScore: Double
                let choice: SpanChoice
                if unis.isEmpty {
                    guard L == 1 else { continue } // no phrase for a multi-reading span
                    spanScore = Self.rawFallbackScore
                    choice = .fallback(range: i..<j, raw: rawSyllables[i])
                } else {
                    // `unis` is already sorted by score descending, so `.first` is the span's best
                    // (pre-userBonus) score used for path selection.
                    spanScore = unis.first?.score ?? Self.rawFallbackScore
                    choice = .phrase(range: i..<j, unigrams: unis)
                }
                let total = best[i] + spanScore
                if total > best[j] {
                    best[j] = total
                    back[j] = choice
                    prev[j] = i
                }
            }
        }

        // Backtrack from n to 0, building each chosen node now. Display order for a phrase span is
        // LM score + user-learning bonus on the leading character.
        var nodes: [WalkNode] = []
        var j = n
        while j > 0, let choice = back[j] {
            switch choice {
            case .fallback(let range, let raw):
                nodes.append(WalkNode(readingRange: range, candidates: [raw]))
            case .phrase(let range, let unigrams):
                let ordered = unigrams.sorted { a, b in
                    let sa = a.score + (a.value.first.map(userBonus) ?? 0)
                    let sb = b.score + (b.value.first.map(userBonus) ?? 0)
                    return sa != sb ? sa > sb : a.value < b.value
                }.map(\.value)
                nodes.append(WalkNode(readingRange: range, candidates: ordered))
            }
            j = prev[j]
        }
        return nodes.reversed()
    }
}
