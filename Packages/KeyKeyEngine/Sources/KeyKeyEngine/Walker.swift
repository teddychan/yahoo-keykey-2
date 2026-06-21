// Minimal Gramambular-style grid + Viterbi walk over unigram log-probs.
public final class ReadingGrid {
    public struct Node {
        public let readingKey: String
        public let spanningLength: Int
        public var unigrams: [Unigram]
        public var overrideIndex: Int?
        public var current: Unigram { unigrams[overrideIndex ?? 0] }
    }

    private let readings: [String]
    private var nodesByStart: [[Node]]   // nodesByStart[i] = nodes beginning at position i
    private static let maxSpan = 6
    private static let fallbackScore = -99.0

    public init(readings: [String], languageModel lm: LanguageModel) {
        self.readings = readings
        self.nodesByStart = Array(repeating: [], count: readings.count)
        for i in 0..<readings.count {
            let maxLen = min(Self.maxSpan, readings.count - i)
            for len in 1...maxLen {
                let key = readings[i..<(i + len)].joined(separator: "-")
                let unigrams = lm.unigrams(forKey: key)
                if !unigrams.isEmpty {
                    nodesByStart[i].append(Node(readingKey: key, spanningLength: len,
                                                unigrams: unigrams, overrideIndex: nil))
                }
            }
            // guarantee a single-syllable node so the walk is total
            if !nodesByStart[i].contains(where: { $0.spanningLength == 1 }) {
                let r = readings[i]
                nodesByStart[i].insert(
                    Node(readingKey: r, spanningLength: 1,
                         unigrams: [Unigram(value: r, score: Self.fallbackScore)],
                         overrideIndex: nil),
                    at: 0)
            }
        }
    }

    // Viterbi over the DAG; returns the chosen nodes' current values.
    public func walk() -> [String] {
        let n = readings.count
        if n == 0 { return [] }
        var best = Array(repeating: -Double.infinity, count: n + 1)
        var fromIndex = Array(repeating: -1, count: n + 1)
        var fromNode = Array(repeating: -1, count: n + 1)
        best[0] = 0
        for i in 0..<n where best[i] > -.infinity {
            for (ni, node) in nodesByStart[i].enumerated() {
                let j = i + node.spanningLength
                let score = best[i] + node.current.score
                if score > best[j] { best[j] = score; fromIndex[j] = i; fromNode[j] = ni }
            }
        }
        var values: [String] = []
        var j = n
        while j > 0 {
            let i = fromIndex[j]
            values.append(nodesByStart[i][fromNode[j]].current.value)
            j = i
        }
        return values.reversed()
    }

    // Candidates overlapping a reading position, longer spans first, then file order.
    public func candidates(at position: Int) -> [String] {
        var spanned: [(span: Int, values: [String])] = []
        for start in 0...position {
            for node in nodesByStart[start]
                where position < start + node.spanningLength {
                spanned.append((node.spanningLength, node.unigrams.map(\.value)))
            }
        }
        spanned.sort { $0.span > $1.span }   // longest phrases first
        return spanned.flatMap(\.values)
    }
}
