import Foundation

/// Splits a latin pinyin string into syllables against a PinyinSyllableTable.
///
/// Uses true backtracking, not pure greedy: it finds the LONGEST prefix of the
/// input that has a *complete* valid segmentation, so a locally-longest syllable
/// that would strand the rest (e.g. `fanguan` → `fang` leaves `uan`) is rejected
/// in favour of one that parses fully (`fan`+`guan`). Among all complete
/// segmentations of that prefix it prefers longest syllables left-to-right, so
/// genuinely ambiguous input keeps the greedy reading (`fangan` → `fang`+`an`).
///
/// `'` is an allowed (zero-width) syllable boundary: a syllable never spans one,
/// and apostrophes are stripped from the output. Any trailing fragment that
/// cannot be parsed is returned as `tail` (kept visible; never dropped, never
/// crashes).
public struct PinyinSegmenter {
    private let table: PinyinSyllableTable
    public init(table: PinyinSyllableTable) { self.table = table }

    public func segment(_ input: String) -> (syllables: [String], tail: String) {
        let scalars = Array(input)
        let n = scalars.count
        let maxLen = max(1, table.maxSyllableLength)

        // scalars[i..<i+len] as a valid syllable (nil if out of range, crosses an
        // apostrophe, or is not in the table).
        func syllable(at i: Int, length len: Int) -> String? {
            guard i + len <= n else { return nil }
            let slice = scalars[i..<(i + len)]
            if slice.contains("'") { return nil }
            let cand = String(slice)
            return table.isValidSyllable(cand) ? cand : nil
        }

        // Advance past apostrophes (zero-width boundaries) to the next real char.
        func skipApostrophes(_ i: Int) -> Int {
            var j = i
            while j < n, scalars[j] == "'" { j += 1 }
            return j
        }

        // canFinish[i] == true  =>  scalars[i..<end] (for some end that is the
        // furthest fully-parsable boundary) splits entirely into valid syllables.
        // Rather than pick `end` up front, we compute reachability of every
        // boundary, take the furthest, then a backward pass tells reconstruction
        // which choices stay on a complete path.

        // Pass 1 (forward): reachable[j] => scalars[0..<j] fully segments.
        var reachable = [Bool](repeating: false, count: n + 1)
        reachable[0] = true
        for i in 0...n where reachable[i] {
            let start = skipApostrophes(i)
            if start != i { reachable[start] = true }
            guard start < n else { continue }
            let upper = min(maxLen, n - start)
            for len in 1...upper where syllable(at: start, length: len) != nil {
                reachable[skipApostrophes(start + len)] = true
            }
        }

        // Furthest fully-segmentable boundary = end of the prefix we consume.
        var furthest = 0
        for j in 0...n where reachable[j] { furthest = j }

        // Pass 2 (backward): reachBack[i] => scalars[i..<furthest] fully segments.
        var reachBack = [Bool](repeating: false, count: n + 1)
        reachBack[furthest] = true
        if furthest >= 1 {
            for i in stride(from: furthest - 1, through: 0, by: -1) {
                let start = skipApostrophes(i)
                if start >= furthest { reachBack[i] = (start == furthest); continue }
                let upper = min(maxLen, furthest - start)
                for len in 1...upper
                where syllable(at: start, length: len) != nil
                    && reachBack[skipApostrophes(start + len)] {
                    reachBack[i] = true
                    break
                }
            }
        }

        // Reconstruct forward: longest-first among choices that still reach `furthest`.
        var syllables: [String] = []
        var i = skipApostrophes(0)
        while i < furthest {
            let upper = min(maxLen, furthest - i)
            var picked = false
            for len in stride(from: upper, through: 1, by: -1) {
                if let s = syllable(at: i, length: len),
                   reachBack[skipApostrophes(i + len)] {
                    syllables.append(s)
                    i = skipApostrophes(i + len)
                    picked = true
                    break
                }
            }
            if !picked { break } // defensive: cannot happen while reachBack[i] holds
        }

        let tail = String(scalars[furthest...].filter { $0 != "'" })
        return (syllables, tail)
    }
}
