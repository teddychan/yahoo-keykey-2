import Foundation

/// A tone-stripped view of the McBopomofo LM, keyed by hyphen-joined TONELESS
/// zhuyin (so toneless pinyin readings can match). Built ONLY when Pinyin is
/// active — never in LanguageModel.init — so Cangjie/Simplex users pay nothing.
///
/// Parses the same "<key> <phrase> <score>" text as LanguageModel, strips the
/// tone marks ˊ ˇ ˋ ˙ (1st tone is already unmarked) from each key, aggregates
/// unigrams that collapse onto the same toneless key (dedup by value, keeping the
/// max score), and stores them sorted by score descending.
public struct TonelessLanguageModelIndex {
    private var table: [String: [Unigram]] = [:]
    /// Longest key length in syllables (hyphen-separated), so the walker can bound spans.
    public private(set) var maxSpanLength: Int = 1

    private static let toneScalars: Set<Character> = ["ˊ", "ˇ", "ˋ", "˙"]

    public init(text: String) {
        // Aggregate best score per (tonelessKey, value).
        var best: [String: [String: Double]] = [:]
        var maxSpan = 1
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ")
            guard parts.count == 3, let score = Double(parts[2]) else { continue }
            let key = String(parts[0]).filter { !Self.toneScalars.contains($0) }
            let value = String(parts[1])
            let span = key.split(separator: "-").count
            if span > maxSpan { maxSpan = span }
            if let existing = best[key]?[value] {
                if score > existing { best[key]?[value] = score }
            } else {
                best[key, default: [:]][value] = score
            }
        }
        for (key, values) in best {
            table[key] = values
                .map { Unigram(value: $0.key, score: $0.value) }
                .sorted { $0.score != $1.score ? $0.score > $1.score : $0.value < $1.value }
        }
        maxSpanLength = maxSpan
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    /// Unigrams for a toneless key, sorted by score descending (best first). Empty if none.
    public func unigrams(forKey key: String) -> [Unigram] { table[key] ?? [] }
}
