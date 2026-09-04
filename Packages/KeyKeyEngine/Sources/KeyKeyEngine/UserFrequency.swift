import Foundation

// User learning / adaptive frequency: remembers how often the user has committed each
// single character and turns that into a ranking bonus, so frequently chosen characters
// surface higher in future candidate lists. Counts persist as JSON across launches.
//
// The bonus is `log(1 + count) * weight`: diminishing returns (so one runaway character
// can't dominate forever) yet a few selections lift a learned character near the top of
// its code's candidates. `weight` is sized to the LM log-probability span (~12) so the
// bonus competes with — but does not blindly override — the language model's ordering.
//
// Designed as a SHARED singleton accessed from multiple IMK threads:
//   - `bonus(for:)` / `record(_:)` are synchronous and thread-safe (guarded by a lock),
//     so the engine can keep calling them inline.
//   - `record` updates the in-memory count immediately (so `bonus` is always current) and
//     schedules a coalesced background save rather than writing on every keystroke.
//   - Distinct entries and single counts are capped to bound the on-disk file.
//
// The `@unchecked Sendable` conformance states that sharing invariant to the compiler, which
// cannot see it on its own. It holds because EVERY stored property is either immutable or
// lock-guarded: `fileURL`, `lock` and `saveQueue` are `let`, and `counts`, `dirty` and
// `saveScheduled` are read and written only while `lock` is held (or in `init`, before the
// instance is shared). Any new stored property must follow that rule or the conformance lapses.
public final class UserFrequency: @unchecked Sendable {
    // The app's own Application Support directory: ~/Library/Application Support/<name>.
    //
    // The name is a REQUIRED parameter, and the app passes a distinct one for a local debug
    // build, because this directory is the only piece of KeyKey's state that the `.debug` bundle
    // id does not separate on its own: `UserDefaults.standard` is the bundle-id domain and the
    // cache dir is `Caches/<bundle id>`, but this was a hardcoded literal shared by the
    // release IME and the debug one. Typing in the debug build therefore trained the installed
    // IME's candidate ranking, and — the reason it had to change — running Uninstall in the
    // debug build deleted it, which MAC-APP-RELEASE-LIFECYCLE.md forbids outright ("uninstall
    // operations must never target the public bundle from Debug").
    //
    // 2.11.2 fixed that by threading an explicit name through from the app. It left `= "YahooKeyKey2"`
    // here, and matching defaults on `defaultFileURL(directory:)` and `init(fileURL:)` below, so the
    // chain still bottomed out on the RELEASE directory: a bare `UserFrequency()` from any build
    // reopened the installed IME's learning data, and the safe value was one omitted argument away.
    // The defaults are gone so the compiler asks the question instead. ice-2 keeps its equivalent
    // default and makes it fail TOWARD the Debug folder (`SettingsBackup.defaultFolder`), which it
    // can do because it may read `Bundle.main.bundleIdentifier`; the right answer here is different
    // because KeyKeyEngine is a pure engine package with no app dependency — not DragonKit, so no
    // `isDebugBuild()`, and teaching it the IME's bundle id would invert that layering. A required
    // argument needs no runtime knowledge at all and cannot be got wrong at runtime.
    public static func supportDirectory(named name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(name)
    }

    // On-disk location within a given directory: <directory>/user-frequency.json. `directory` is
    // required for the reason on `supportDirectory(named:)` above — it used to default to the
    // release directory, which is what let the whole chain bottom out there.
    public static func defaultFileURL(directory: URL) -> URL {
        directory.appendingPathComponent("user-frequency.json")
    }

    private static let weight = 10.0
    // Bound the file: cap distinct learned characters (evict least-used past this), and
    // cap any single count so the log-bonus can't grow unbounded.
    private static let maxEntries = 5000
    private static let maxCount = 100_000
    private static let saveDelay: TimeInterval = 5

    private let fileURL: URL
    private let lock = NSLock()
    private let saveQueue = DispatchQueue(label: "YahooKeyKey2.UserFrequency.save", qos: .background)
    private var counts: [Character: Int]
    private var dirty = false           // a save is pending/coalescing
    private var saveScheduled = false   // a debounced save is already queued

    // `fileURL` is required: see `supportDirectory(named:)`. A defaulted one meant `UserFrequency()`
    // opened the installed release IME's counts from whatever build called it.
    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.counts = UserFrequency.load(from: fileURL)
    }

    /// Ranking bonus for `char`, added on top of its LM score. Zero for unseen characters.
    public func bonus(for char: Character) -> Double {
        lock.lock()
        let count = counts[char] ?? 0
        lock.unlock()
        guard count > 0 else { return 0 }
        return log(1 + Double(count)) * Self.weight
    }

    /// Record one user selection of `char`. Updates the in-memory count immediately and
    /// schedules a coalesced background save. Thread-safe.
    public func record(_ char: Character) {
        lock.lock()
        let current = counts[char] ?? 0
        // Cap a single count to bound the file; once at the cap the entry just stays.
        counts[char] = min(current + 1, Self.maxCount)
        evictIfNeededLocked()
        dirty = true
        let shouldSchedule = !saveScheduled
        if shouldSchedule { saveScheduled = true }
        lock.unlock()

        if shouldSchedule {
            saveQueue.asyncAfter(deadline: .now() + Self.saveDelay) { [weak self] in
                self?.flushIfDirty()
            }
        }
    }

    /// Synchronously persist now if there are unsaved changes (e.g. on app termination).
    public func flush() {
        flushIfDirty()
    }

    // MARK: - Internal

    // Drop the least-used entries when distinct entries exceed the cap. Caller holds `lock`.
    private func evictIfNeededLocked() {
        guard counts.count > Self.maxEntries else { return }
        let overflow = counts.count - Self.maxEntries
        // Evict the lowest counts first (ties broken arbitrarily — they're the coldest).
        let victims = counts.sorted { $0.value < $1.value }.prefix(overflow).map(\.key)
        for key in victims { counts.removeValue(forKey: key) }
    }

    private func flushIfDirty() {
        lock.lock()
        guard dirty else { lock.unlock(); return }
        let snapshot = counts
        dirty = false
        saveScheduled = false
        lock.unlock()
        UserFrequency.save(snapshot, to: fileURL)
    }

    // MARK: - Persistence

    // Persisted as a [String: Int] map (JSON has no Character key type), one char per key.
    private static func load(from url: URL) -> [Character: Int] {
        // No file yet is the normal first-launch case, not a failure: start empty, say nothing.
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: Int].self, from: data) else {
            // The file is there but unreadable. Silently returning [:] here reset the user's
            // learning with no signal, and the next debounced save then overwrote the evidence.
            // Log it (file name only — the full path carries the user's home directory) and move
            // the bad file aside so it survives for diagnosis.
            NSLog("YahooKeyKey: \(url.lastPathComponent) unreadable; starting with empty user frequency")
            quarantine(url)
            return [:]
        }
        var result: [Character: Int] = [:]
        for (key, value) in raw where key.unicodeScalars.count == 1 {
            if let ch = key.first { result[ch] = value }
        }
        return result
    }

    // Move an unreadable store aside as "<name>.corrupt" so the next save writes a fresh file
    // instead of overwriting the broken one, keeping it around to diagnose. Best-effort: if the
    // move fails there is nothing more to do — the store is already lost either way.
    private static func quarantine(_ url: URL) {
        let corrupt = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".corrupt")
        try? FileManager.default.removeItem(at: corrupt)   // replace any earlier quarantine
        do {
            try FileManager.default.moveItem(at: url, to: corrupt)
        } catch {
            NSLog("YahooKeyKey: could not set aside the unreadable user frequency store: \(error)")
        }
    }

    private static func save(_ counts: [Character: Int], to url: URL) {
        let raw = Dictionary(uniqueKeysWithValues: counts.map { (String($0.key), $0.value) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("YahooKeyKey: failed to persist user frequency: \(error)")
        }
    }
}
