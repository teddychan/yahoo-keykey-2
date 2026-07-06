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

        // DP over prefix boundaries: best[j] = best total score covering readings[0..<j].
        var best = [Double](repeating: -.greatestFiniteMagnitude, count: n + 1)
        var back = [WalkNode?](repeating: nil, count: n + 1)
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
                let node: WalkNode
                if unis.isEmpty {
                    guard L == 1 else { continue } // no phrase for a multi-reading span
                    spanScore = Self.rawFallbackScore
                    node = WalkNode(readingRange: i..<j, candidates: [rawSyllables[i]])
                } else {
                    spanScore = unis.first?.score ?? Self.rawFallbackScore
                    // Display order: LM score + user-learning bonus on the leading character.
                    let ordered = unis.sorted { a, b in
                        let sa = a.score + (a.value.first.map(userBonus) ?? 0)
                        let sb = b.score + (b.value.first.map(userBonus) ?? 0)
                        return sa != sb ? sa > sb : a.value < b.value
                    }.map(\.value)
                    node = WalkNode(readingRange: i..<j, candidates: ordered)
                }
                let total = best[i] + spanScore
                if total > best[j] {
                    best[j] = total
                    back[j] = node
                    prev[j] = i
                }
            }
        }

        // Backtrack from n to 0.
        var nodes: [WalkNode] = []
        var j = n
        while j > 0, let node = back[j] {
            nodes.append(node)
            j = prev[j]
        }
        return nodes.reversed()
    }
}
