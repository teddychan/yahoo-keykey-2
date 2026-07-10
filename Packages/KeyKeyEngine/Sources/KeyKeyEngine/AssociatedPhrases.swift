import Foundation

// Associated phrases (聯想詞): multi-character words indexed by their first character,
// loaded from the McBopomofo "sorted" LM. Format per line: "<reading> <phrase> <score>".
public struct AssociatedPhrases {
    private static let maxPerBucket = 20

    private var table: [Character: [String]] = [:]

    /// Builds from already-split LM lines. Callers that already have the file split into
    /// lines (e.g. to also build `LanguageModel.characterScores` from the same lines) should
    /// use this to avoid re-splitting the same multi-MB text.
    public init(lines: [Substring]) {
        var scored: [Character: [(phrase: String, score: Double)]] = [:]
        scored.reserveCapacity(6_000)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ")
            guard parts.count == 3, let score = Double(parts[2]) else { continue }
            let phrase = String(parts[1])
            guard phrase.count >= 2, let first = phrase.first else { continue }
            scored[first, default: []].append((phrase, score))
        }
        table.reserveCapacity(scored.count)
        for (first, entries) in scored {
            var seen = Set<String>()
            var phrases: [String] = []
            for entry in entries.sorted(by: { $0.score > $1.score }) {
                if seen.insert(entry.phrase).inserted {
                    phrases.append(entry.phrase)
                    if phrases.count == Self.maxPerBucket { break }
                }
            }
            table[first] = phrases
        }
    }

    public init(text: String) {
        self.init(lines: text.split(separator: "\n", omittingEmptySubsequences: true))
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public func associations(for first: Character) -> [String] { table[first] ?? [] }
}
