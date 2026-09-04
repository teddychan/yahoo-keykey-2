import Foundation

// Per-candidate-list commit counts: how many times the user has committed each candidate
// *within the list it was offered in* (see CandidateListKey). That count is the whole of
// adaptive ordering — a candidate with more commits ranks first, and equal counts fall back
// to the built-in order. Nothing here is combined with a language-model score, weighted, or
// aged: a count is a count.
//
// This SUPERSEDES the retired `user-frequency.json`, which held one global count per character
// with no record of which list it was committed in. Those counts cannot be mapped onto per-list
// history — the file does not say which mode, table version, code, wildcard pattern or
// association trigger produced them — so this store starts empty rather than pretending. The
// legacy file is left on disk untouched (a downgrade still finds its data); `legacyFileURL` names
// it so the uninstall sweep and its test can see both files live in one directory.
//
// Designed as a SHARED singleton accessed from multiple IMK threads, keeping the reliability
// the retired store had:
//   - `count(of:in:)` / `record(_:in:)` are synchronous and thread-safe (guarded by a lock),
//     so the engines can keep calling them inline while sorting.
//   - `record` updates the in-memory count immediately (so `count` is always current) and
//     schedules a coalesced background save rather than writing on every keystroke.
//   - Distinct records and single counts are capped to bound the on-disk file, and eviction is
//     deterministic so two stores fed the same commits hold the same data.
//
// The `@unchecked Sendable` conformance states that sharing invariant to the compiler, which
// cannot see it on its own. It holds because EVERY stored property is either immutable or
// lock-guarded: `fileURL`, `lock` and `saveQueue` are `let`, and `counts`, `dirty` and
// `saveScheduled` are read and written only while `lock` is held (or in `init`, before the
// instance is shared). Any new stored property must follow that rule or the conformance lapses.
public final class CandidateUsageStore: @unchecked Sendable {
    /// On-disk format version. A file carrying any other version is quarantined rather than
    /// parsed or overwritten, so neither a future version's data nor a corrupt file is destroyed.
    public static let formatVersion = 1

    // Bound the file: cap distinct (list, candidate) records — evicting the least-used past this
    // — and cap any single count. Higher than the retired store's 5,000 characters because a
    // per-list store necessarily holds one record per list a candidate appears in, but still a
    // few hundred KB of JSON at the cap.
    public static let maxEntries = 20_000
    public static let maxCount = 100_000
    private static let saveDelay: TimeInterval = 5

    private let fileURL: URL
    private let lock = NSLock()
    private let saveQueue = DispatchQueue(label: "YahooKeyKey2.CandidateUsageStore.save", qos: .background)
    private var counts: [CandidateListKey: [String: Int]]
    private var dirty = false           // a save is pending/coalescing
    private var saveScheduled = false   // a debounced save is already queued

    // The app's own Application Support directory: ~/Library/Application Support/<name>.
    //
    // The name is a REQUIRED parameter, and the app passes a distinct one for a local debug
    // build, because this directory is the only piece of KeyKey's state that the `.debug` bundle
    // id does not separate on its own: `UserDefaults.standard` is the bundle-id domain and the
    // cache dir is `Caches/<bundle id>`, but this was once a hardcoded literal shared by the
    // release IME and the debug one. Typing in the debug build therefore trained the installed
    // IME's candidate ranking, and — the reason it had to change — running Uninstall in the
    // debug build deleted it, which MAC-APP-RELEASE-LIFECYCLE.md forbids outright ("uninstall
    // operations must never target the public bundle from Debug"). There is deliberately no
    // default value, so the compiler asks the question rather than failing toward the release
    // directory; KeyKeyEngine is a pure engine package that cannot read the bundle id itself.
    public static func supportDirectory(named name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(name)
    }

    /// On-disk location within a given directory: `<directory>/candidate-usage.json`. `directory`
    /// is required for the reason on `supportDirectory(named:)`.
    public static func defaultFileURL(directory: URL) -> URL {
        directory.appendingPathComponent("candidate-usage.json")
    }

    /// The RETIRED global-per-character store from 2.13.3 and earlier. Nothing reads or writes it
    /// any more; it is named here because it sits in the same directory as the new file, which is
    /// what makes the Uninstall pane's single directory sweep remove both learning files.
    public static func legacyFileURL(directory: URL) -> URL {
        directory.appendingPathComponent("user-frequency.json")
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.counts = CandidateUsageStore.load(from: fileURL)
    }

    /// How many times `candidate` has been committed in `list`. Zero for anything unseen —
    /// which, in a fresh store, is every candidate, so every list keeps its built-in order.
    public func count(of candidate: String, in list: CandidateListKey) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[list]?[candidate] ?? 0
    }

    /// Record one commit of `candidate` in `list`. Updates the in-memory count immediately and
    /// schedules a coalesced background save. Thread-safe.
    public func record(_ candidate: String, in list: CandidateListKey) {
        lock.lock()
        let current = counts[list]?[candidate] ?? 0
        // Cap a single count to bound the file; once at the cap the record just stays.
        counts[list, default: [:]][candidate] = min(current + 1, Self.maxCount)
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

    /// Total (list, candidate) records held. Exposed for the storage-bound test.
    public var entryCountForTesting: Int {
        lock.lock()
        defer { lock.unlock() }
        return counts.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Internal

    // Drop the least-used records when the total exceeds the cap. Caller holds `lock`.
    //
    // The order is fully determined — count, then the record's fields — so a store fed the same
    // commits always evicts the same records. The retired store broke count ties "arbitrarily",
    // which was fine for a debug aid but would make this store's contents depend on dictionary
    // iteration order.
    private func evictIfNeededLocked() {
        var total = 0
        for candidates in counts.values { total += candidates.count }
        guard total > Self.maxEntries else { return }
        let overflow = total - Self.maxEntries
        var flat: [(list: CandidateListKey, candidate: String, count: Int)] = []
        flat.reserveCapacity(total)
        for (list, candidates) in counts {
            for (candidate, count) in candidates { flat.append((list, candidate, count)) }
        }
        let victims = flat.sorted { Self.evictsFirst($0, $1) }.prefix(overflow)
        for victim in victims {
            counts[victim.list]?.removeValue(forKey: victim.candidate)
            if counts[victim.list]?.isEmpty == true { counts.removeValue(forKey: victim.list) }
        }
    }

    // Coldest first, with every tie broken, so eviction is reproducible.
    private static func evictsFirst(_ a: (list: CandidateListKey, candidate: String, count: Int),
                                    _ b: (list: CandidateListKey, candidate: String, count: Int)) -> Bool {
        if a.count != b.count { return a.count < b.count }
        let aFields = [a.list.scopeName, a.list.tableVersionField ?? "", a.list.codeField ?? "",
                       a.list.triggerField ?? "", a.candidate]
        let bFields = [b.list.scopeName, b.list.tableVersionField ?? "", b.list.codeField ?? "",
                       b.list.triggerField ?? "", b.candidate]
        for (lhs, rhs) in zip(aFields, bFields) where lhs != rhs { return lhs < rhs }
        return false
    }

    private func flushIfDirty() {
        lock.lock()
        guard dirty else { lock.unlock(); return }
        let snapshot = counts
        dirty = false
        saveScheduled = false
        lock.unlock()
        CandidateUsageStore.save(snapshot, to: fileURL)
    }

    // MARK: - Persistence

    // One record per list, with the list's identity in NAMED fields rather than a joined string,
    // so a code containing any character at all cannot be read back as a different list.
    private struct StoredList: Codable {
        let scope: String
        let tableVersion: String?
        let code: String?
        let trigger: String?
        let counts: [String: Int]
    }

    private struct StoredFile: Codable {
        let version: Int
        let lists: [StoredList]
    }

    private static func load(from url: URL) -> [CandidateListKey: [String: Int]] {
        // No file yet is the normal first-launch case, not a failure: start empty, say nothing.
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(StoredFile.self, from: data),
              file.version == formatVersion else {
            // The file is there but not something this version can read. Silently returning [:]
            // would reset the user's learning with no signal and let the next debounced save
            // overwrite the evidence. Log it (file name only — the full path carries the user's
            // home directory) and move the bad file aside so it survives, whether it is corrupt
            // or simply written by a newer version than this build understands.
            NSLog("YahooKeyKey: \(url.lastPathComponent) unreadable; starting with empty candidate usage")
            quarantine(url)
            return [:]
        }
        var result: [CandidateListKey: [String: Int]] = [:]
        result.reserveCapacity(file.lists.count)
        for stored in file.lists {
            guard let key = CandidateListKey.make(scope: stored.scope, tableVersion: stored.tableVersion,
                                                  code: stored.code, trigger: stored.trigger) else { continue }
            // A record for a list already seen merges rather than replaces, so a hand-edited or
            // duplicated file cannot silently drop counts.
            for (candidate, count) in stored.counts where count > 0 {
                result[key, default: [:]][candidate, default: 0] += min(count, maxCount)
            }
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
            NSLog("YahooKeyKey: could not set aside the unreadable candidate usage store: \(error)")
        }
    }

    private static func save(_ counts: [CandidateListKey: [String: Int]], to url: URL) {
        // Sorted by the same total order eviction uses, so the file is byte-stable for a given
        // set of counts instead of following dictionary iteration order.
        let lists = counts.map { list, candidates in
            StoredList(scope: list.scopeName, tableVersion: list.tableVersionField,
                       code: list.codeField, trigger: list.triggerField, counts: candidates)
        }.sorted {
            let lhs = [$0.scope, $0.tableVersion ?? "", $0.code ?? "", $0.trigger ?? ""]
            let rhs = [$1.scope, $1.tableVersion ?? "", $1.code ?? "", $1.trigger ?? ""]
            for (l, r) in zip(lhs, rhs) where l != r { return l < r }
            return false
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(StoredFile(version: formatVersion, lists: lists)) else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("YahooKeyKey: failed to persist candidate usage: \(error)")
        }
    }
}
