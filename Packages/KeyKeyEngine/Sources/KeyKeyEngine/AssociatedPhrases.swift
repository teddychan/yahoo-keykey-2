import Foundation

// Associated phrases (聯想詞): multi-character words indexed by their first character,
// loaded from the McBopomofo "sorted" LM. Format per line: "<reading> <phrase> <score>".
public struct AssociatedPhrases {
    private static let maxPerBucket = 20

    // A phrase and the LM score it was loaded with. The score is KEPT rather than consumed by a
    // load-time sort because ordering is decided per query: `associations(for:userRank:)` adds the
    // live user-learning bonus on top of it (issue #85), and that bonus changes as the user types.
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
                    // out of reach in the 9-per-page window whatever the user bonus does to it.
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
    /// Ordered by LM score plus the live user-learning bonus for each phrase's CONTINUATION
    /// character — 係 in 關係 — which is the character the user is actually choosing to add, and
    /// what the 聯想只顯示接續字 display option already shows. The phrase's FIRST character would
    /// be the wrong input: it is this bucket's index key, identical for every phrase in it, so its
    /// bonus is a constant that reorders nothing.
    ///
    /// With the default (zero) bonus the static LM order is preserved exactly, so a caller that
    /// does not opt into user learning sees what it always saw. Ties resolve by the bucket's own
    /// order, so the result is reproducible.
    public func associations(for first: Character,
                             userRank: (Character) -> Double = { _ in 0 }) -> [String] {
        guard let entries = table[first] else { return [] }
        // Score each entry ONCE, then sort the (offset, phrase, score) triples — same shape as
        // CangjieEngine/SimplexEngine.computeCandidates.
        return entries.enumerated().map { offset, entry in
            (offset, entry.phrase, entry.score + (entry.phrase.dropFirst().first.map(userRank) ?? 0))
        }.sorted { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
            return lhs.0 < rhs.0
        }.map(\.1)
    }
}
