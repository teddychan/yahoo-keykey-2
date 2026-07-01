import Foundation

// Simplex (簡易) index: maps a 2-letter "quick" code to the characters that share it.
// The Simplex code of a Cangjie code is its first + last radical letter (a single
// letter when the Cangjie code has length 1). Many Cangjie codes collapse onto the
// same Simplex code, so candidate lists are larger than full Cangjie.
public struct SimplexTable {
    private var table: [String: [String]] = [:]
    // Shadow membership sets per simplex code, used only during construction for
    // O(1) dedup instead of an O(n) `array.contains` scan per insert.
    private var seen: [String: Set<String>] = [:]

    /// Builds the index from a full CangjieTable. Entries are processed in sorted
    /// Cangjie-code order so the grouped candidate lists are deterministic
    /// (forEachEntry's own order is unspecified).
    public init(cangjie: CangjieTable) {
        var entries: [(String, [String])] = []
        cangjie.forEachEntry { code, chars in entries.append((code, chars)) }
        for (code, chars) in entries.sorted(by: { $0.0 < $1.0 }) {
            let simplex = Self.simplexCode(for: code)
            guard !simplex.isEmpty else { continue }
            for char in chars { add(char, to: simplex) }
        }
    }

    /// Builds the index directly from already-Simplex-coded "<quickCode>\t<char>" lines,
    /// preserving the file's native character order per code (no first+last re-derivation).
    /// Used for the Yahoo! KeyKey 速成 table (simplex-ext.cin), whose rows are already quick
    /// codes and whose line order is the intended candidate order.
    public init(quickCodeText: String) {
        for rawLine in quickCodeText.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let code = String(parts[0])
            guard !code.isEmpty else { continue }
            add(String(parts[1]), to: code)
        }
    }

    public init(quickCodeContentsOf url: URL) throws {
        try self.init(quickCodeText: String(contentsOf: url, encoding: .utf8))
    }

    /// Builds the index directly from "<cangjieCode>\t<char>" lines (test fixtures).
    public init(text: String) {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let simplex = Self.simplexCode(for: String(parts[0]))
            guard !simplex.isEmpty else { continue }
            add(String(parts[1]), to: simplex)
        }
    }

    public func characters(forCode code: String) -> [String] { table[code] ?? [] }

    private mutating func add(_ char: String, to simplex: String) {
        if seen[simplex, default: []].insert(char).inserted {
            table[simplex, default: []].append(char)
        }
    }

    private static func simplexCode(for cangjieCode: String) -> String {
        guard let first = cangjieCode.first, let last = cangjieCode.last else { return "" }
        return cangjieCode.count == 1 ? String(first) : String(first) + String(last)
    }
}
