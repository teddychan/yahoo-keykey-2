// Candidate order for the single-character lists (倉頡 and 速成).
//
// Frequency first, built-in order second — and nothing else. How often the user has committed
// a candidate IN THIS LIST decides the order; when two candidates have been committed the same
// number of times (including the usual case of never), the built-in order decides. The counts
// are never added to, scaled against or traded off with the language-model score, so a single
// commit is enough to put a candidate ahead of every candidate the user has not committed —
// including one the language model has never heard of, which is what issue #130 reported.
//
// The built-in baseline is the ordering this list had before any learning:
//   - two candidates the language model ranks: the higher rank first;
//   - a ranked candidate against an unranked one: the ranked one first;
//   - two unranked candidates: the order the table gave them.
// The ranks are compared AS OPTIONALS. An earlier version stood in a magic `-1e9` for "unranked"
// so it could add a learned bonus to it, which meant the sort's correctness rested on that number
// staying below every real log-probability and above what any bonus could climb. With counts
// sorted first and separately there is nothing to add, so the absent rank can simply be absent.
//
// With a fresh store every count is zero, which leaves the baseline alone: the result is
// byte-for-byte what the table and rank produced before adaptive ordering existed. 三代 supplies
// an empty rank, so every candidate is unranked and the table's own order is what shows.
enum CandidateOrdering {
    /// `candidates` reordered frequency-first over their built-in order.
    ///
    /// `rank` is the language model's single-character ranking (higher = more common); a
    /// character absent from it is unranked. `usageCount` answers how many times a candidate has
    /// been committed in the list being ordered — the caller has already fixed which list that is.
    static func ordered(_ candidates: [String],
                        rank: [Character: Double],
                        usageCount: (String) -> Int) -> [String] {
        // Score each candidate ONCE (usageCount reaches a locked store), then sort the tuples.
        // The source offset is carried so the comparator can be a total order, which is what
        // makes ties resolve to the built-in order rather than to sort implementation details.
        return candidates.enumerated().map { offset, candidate in
            (offset: offset, candidate: candidate,
             count: usageCount(candidate), rank: candidate.first.flatMap { rank[$0] })
        }.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            switch (lhs.rank, rhs.rank) {
            case (let l?, let r?) where l != r: return l > r   // both ranked: higher first
            case (.some, .none): return true                   // ranked before unranked
            case (.none, .some): return false
            default: break                                     // equal ranks, or both unranked
            }
            return lhs.offset < rhs.offset                     // built-in order
        }.map(\.candidate)
    }
}
