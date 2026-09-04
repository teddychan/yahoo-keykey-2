import Foundation

// Associated phrases (聯想詞): multi-character words indexed by their first character,
// loaded from the McBopomofo "sorted" LM. Format per line: "<reading> <phrase> <score>".
public struct AssociatedPhrases {
    private static let maxPerBucket = 20

    // A phrase and the LM score it was loaded with. The score is KEPT rather than consumed by a
    // load-time sort because ordering is decided per query: `associations(for:usageCount:)` sorts
    // the bucket by how often each phrase has been committed first and falls back to this score,
    // and those counts change as the user types.
    private struct Entry {
        let phrase: String
        let score: Double
    }

    private var table: [Character: [Entry]] = [:]

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
            var kept: [Entry] = []
            // Ties broken by the order the lines were read. `sorted(by:)` is NOT a stable sort, so
            // score alone left equal-scoring phrases in an arbitrary order — and because this sort
            // feeds the cap below, that arbitrariness decided WHICH phrases survive, i.e. which
            // ones the user can ever see. The offset makes the bucket reproducible.
            let ordered = entries.enumerated().sorted { lhs, rhs in
                if lhs.element.score != rhs.element.score { return lhs.element.score > rhs.element.score }
                return lhs.offset < rhs.offset
            }
            for (_, entry) in ordered {
                if seen.insert(entry.phrase).inserted {
                    kept.append(Entry(phrase: entry.phrase, score: entry.score))
                    // Cap at load: it bounds memory, and a phrase below the top 20 by LM score is
                    // out of reach in the 9-per-page window whatever its committed count does to it.
                    if kept.count == Self.maxPerBucket { break }
                }
            }
            table[first] = kept
        }
    }

    public init(text: String) {
        self.init(lines: text.split(separator: "\n", omittingEmptySubsequences: true))
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    /// The phrases suggested after `first` was committed, best first.
    ///
    /// Ordered by how many times each phrase has been committed in THIS trigger's list, with the
    /// LM score (then the bucket's own order) as the tie-breaker — the same frequency-first rule
    /// the 倉頡/速成 lists follow, and nothing added to or traded against the score.
    ///
    /// `usageCount` is asked about the WHOLE phrase — 關係, not the continuation 係 — because the
    /// phrase is what this list offers and what a pick commits. That stays true when the
    /// 聯想只顯示接續字 display option shows only 係: the row displayed is shortened, the candidate
    /// picked is not.
    ///
    /// With the default (zero) counts the static LM order is preserved exactly, so a caller that
    /// does not opt into learning sees what it always saw.
    public func associations(for first: Character,
                             usageCount: (String) -> Int = { _ in 0 }) -> [String] {
        guard let entries = table[first] else { return [] }
        // Read each count ONCE (it reaches a locked store), then sort the tuples.
        return entries.enumerated().map { offset, entry in
            (offset: offset, phrase: entry.phrase, count: usageCount(entry.phrase), score: entry.score)
        }.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.offset < rhs.offset
        }.map(\.phrase)
    }
}
