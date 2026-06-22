import Foundation

public struct Unigram: Equatable {
    public let value: String
    public let score: Double
    public init(value: String, score: Double) { self.value = value; self.score = score }
}

// Loads the McBopomofo "sorted" plain-text LM. Format per line: "<key> <phrase> <score>".
public struct LanguageModel {
    private var table: [String: [Unigram]] = [:]

    public init(text: String) {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ")
            guard parts.count == 3, let score = Double(parts[2]) else { continue }
            let key = String(parts[0])
            table[key, default: []].append(Unigram(value: String(parts[1]), score: score))
        }
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public func unigrams(forKey key: String) -> [Unigram] { table[key] ?? [] }
    public func hasKey(_ key: String) -> Bool { table[key] != nil }

    /// Maps each single-character value to the MAX score seen for it across all
    /// unigrams. Multi-character values are excluded. Higher score = more common.
    public func characterScores() -> [Character: Double] {
        var scores: [Character: Double] = [:]
        for grams in table.values {
            for g in grams where g.value.count == 1 {
                let ch = g.value.first!
                if let existing = scores[ch] { scores[ch] = max(existing, g.score) }
                else { scores[ch] = g.score }
            }
        }
        return scores
    }
}
