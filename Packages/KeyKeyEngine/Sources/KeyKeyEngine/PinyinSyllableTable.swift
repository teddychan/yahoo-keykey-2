import Foundation

/// Maps a Hanyu Pinyin syllable (e.g. "hao") to its toneless zhuyin reading
/// (e.g. "ㄏㄠ"). `ü`-syllables are keyed under their `v` spelling (see the
/// generator, tools/build-pinyin-map.py). Line format: "<pinyin>\t<zhuyin>".
public struct PinyinSyllableTable {
    private var map: [String: String] = [:]
    private var reverse: [String: String] = [:]   // toneless zhuyin → pinyin (first spelling wins)
    /// Longest pinyin syllable, so the segmenter can bound its longest-match window.
    public private(set) var maxSyllableLength: Int = 0

    public init(text: String) {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let pinyin = String(parts[0])
            let zhuyin = String(parts[1])
            guard !pinyin.isEmpty, !zhuyin.isEmpty else { continue }
            map[pinyin] = zhuyin
            if reverse[zhuyin] == nil { reverse[zhuyin] = pinyin }
            maxSyllableLength = max(maxSyllableLength, pinyin.count)
        }
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: String(contentsOf: url, encoding: .utf8))
    }

    public func isValidSyllable(_ s: String) -> Bool { map[s] != nil }
    public func zhuyin(forSyllable s: String) -> String? { map[s] }
    /// The pinyin syllable for a toneless zhuyin reading (reverse of `zhuyin(forSyllable:)`), or nil.
    public func pinyin(forZhuyin z: String) -> String? { reverse[z] }
    public var syllableCount: Int { map.count }
}
