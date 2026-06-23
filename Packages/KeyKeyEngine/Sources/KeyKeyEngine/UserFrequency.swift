import Foundation

// User learning / adaptive frequency: remembers how often the user has committed each
// single character and turns that into a ranking bonus, so frequently chosen characters
// surface higher in future candidate lists. Counts persist as JSON across launches.
//
// The bonus is `log(1 + count) * weight`: diminishing returns (so one runaway character
// can't dominate forever) yet a few selections lift a learned character near the top of
// its code's candidates. `weight` is sized to the LM log-probability span (~12) so the
// bonus competes with — but does not blindly override — the language model's ordering.
public final class UserFrequency {
    // Default on-disk location: ~/Library/Application Support/YahooKeyKey2/user-frequency.json
    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("YahooKeyKey2").appendingPathComponent("user-frequency.json")
    }

    private static let weight = 10.0

    private let fileURL: URL
    private var counts: [Character: Int]

    public init(fileURL: URL = UserFrequency.defaultFileURL()) {
        self.fileURL = fileURL
        self.counts = UserFrequency.load(from: fileURL)
    }

    /// Ranking bonus for `char`, added on top of its LM score. Zero for unseen characters.
    public func bonus(for char: Character) -> Double {
        guard let count = counts[char], count > 0 else { return 0 }
        return log(1 + Double(count)) * Self.weight
    }

    /// Record one user selection of `char`, then persist. Fail-safe: a write error is logged
    /// and dropped (the in-memory count still applies for this session).
    public func record(_ char: Character) {
        counts[char, default: 0] += 1
        save()
    }

    // MARK: - Persistence

    // Persisted as a [String: Int] map (JSON has no Character key type), one char per key.
    private static func load(from url: URL) -> [Character: Int] {
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        var result: [Character: Int] = [:]
        for (key, value) in raw where key.count == 1 {
            result[key.first!] = value
        }
        return result
    }

    private func save() {
        let raw = Dictionary(uniqueKeysWithValues: counts.map { (String($0.key), $0.value) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("YahooKeyKey: failed to persist user frequency: \(error)")
        }
    }
}
