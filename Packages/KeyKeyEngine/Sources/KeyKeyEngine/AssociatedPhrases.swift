import Foundation

// Associated phrases (聯想詞): multi-character words indexed by their first character,
// loaded from the McBopomofo "sorted" LM. Format per line: "<reading> <phrase> <score>".
public struct AssociatedPhrases {
    private static let maxPerBucket = 20

    private var table: [Character: [String]] = [:]

    public init(text: String) {
        var scored: [Character: [(phrase: String, score: Double)]] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ")
            guard parts.count == 3, let score = Double(parts[2]) else { continue }
            let phrase = String(parts[1])
            guard phrase.count >= 2, let first = phrase.first else { continue }
            scored[first, default: []].append((phrase, score))
        }
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

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public func associations(for first: Character) -> [String] { table[first] ?? [] }
}
