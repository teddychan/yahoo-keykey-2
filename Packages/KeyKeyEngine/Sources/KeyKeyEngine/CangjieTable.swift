import Foundation

// Maps a Cangjie letter-sequence code (e.g. "ab") to the characters that share it.
// Line format: "<code>\t<char>", one mapping per line (matches Resources/cangjie.txt).
public struct CangjieTable {
    private var table: [String: [String]] = [:]
    // Compiled-regex cache for wildcard patterns. A reference-type box so the cache
    // survives across calls on a `let`-bound (non-mutating) table; the set of distinct
    // wildcard patterns the user types is tiny, so this stays small.
    private final class RegexCache {
        private var cache: [String: NSRegularExpression] = [:]
        func regex(for pattern: String) -> NSRegularExpression? {
            if let cached = cache[pattern] { return cached }
            guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
            cache[pattern] = re
            return re
        }
    }
    private let regexCache = RegexCache()

    public init(text: String) {
        table.reserveCapacity(70_000)
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let char = String(parts[1])
            guard let ch = char.first, char.count == 1, Self.isRenderableCJK(ch) else { continue }
            let code = String(parts[0])
            table[code, default: []].append(char)
        }
    }

    /// True only for single-scalar characters we can render safely: the common CJK
    /// ideograph ranges, plus the CJK punctuation/full-width ranges used by the Yahoo
    /// table's `z`-code punctuation (e.g. `zxcd`→「, `zxab`→，). Drops Private Use Areas
    /// and supplementary-plane ideographs (Ext-B and beyond), which render as tofu.
    static func isRenderableCJK(_ ch: Character) -> Bool {
        let scalars = ch.unicodeScalars
        guard scalars.count == 1, let v = scalars.first?.value else { return false }
        return (0x4E00...0x9FFF).contains(v)   // CJK Unified Ideographs
            || (0x3400...0x4DBF).contains(v)   // CJK Extension A
            || (0xF900...0xFAFF).contains(v)   // CJK Compatibility Ideographs
            || (0x3000...0x303F).contains(v)   // CJK Symbols and Punctuation (、。「」『』…)
            || (0xFE30...0xFE4F).contains(v)   // CJK Compatibility Forms (vertical ︰﹁ etc.)
            || (0xFF00...0xFFEF).contains(v)   // Halfwidth & Fullwidth Forms (，（）：？！)
            || (0x2010...0x2027).contains(v)   // General punctuation used by z-codes (–—‥…)
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public func characters(forCode code: String) -> [String] { table[code] ?? [] }
    public func hasCode(_ code: String) -> Bool { table[code] != nil }

    /// Iterates every (code, characters) entry in insertion-independent order.
    public func forEachEntry(_ body: (String, [String]) -> Void) {
        for (code, chars) in table { body(code, chars) }
    }

    /// Returns characters whose code matches `pattern`. `*` matches one-or-more
    /// letters (a–z); other characters match literally. With no `*`, behaves like
    /// an exact `characters(forCode:)`. Results are ordered by matched code length
    /// then the table's character order for that code (deterministic).
    public func characters(matching pattern: String) -> [String] {
        guard pattern.contains("*") else { return characters(forCode: pattern) }
        let regex = "^" + pattern.split(separator: "*", omittingEmptySubsequences: false)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: "[a-z]+") + "$"
        guard let re = regexCache.regex(for: regex) else { return [] }
        let matched = table.keys.filter {
            re.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil
        }
        return matched.sorted { ($0.count, $0) < ($1.count, $1) }
            .flatMap { table[$0] ?? [] }
    }
}
