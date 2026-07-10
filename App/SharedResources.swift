import Cocoa
import KeyKeyEngine

// Process-wide, load-once store for the heavy IME resources. IMK creates one
// InputController per client (per app), so loading these per instance duplicated
// ~55–80 MB across every app. This singleton loads each resource exactly once and
// every controller reads from it; the engine types are value-type structs (and
// UserFrequency is a shared class), so reads do not copy.
final class SharedResources {
    static let shared = SharedResources()

    // Single-character LM ranking (higher = more common), used so Cangjie/Simplex
    // wildcard matches surface common characters first. Computed once.
    let characterRank: [Character: Double]
    let associatedPhrases: AssociatedPhrases
    // Cangjie table and the effective sort rank depend on the selected Cangjie version;
    // rebuilt in place by reloadCangjieTables() when the user changes it.
    private(set) var cangjieTable: CangjieTable
    // Single-char rank the engines sort by: the LM `characterRank` for 五代, or empty for
    // 三代 so the Yahoo table's native line order is preserved. User-learning applies on top.
    private(set) var cangjieRank: [Character: Double]
    let hanConvertFilter: HanConvertFilter
    // One shared user-learning store across all controllers.
    let userFreq: UserFrequency
    // Small pinyin→zhuyin syllable map (eager; ~422 rows, tiny). Backs the Pinyin segmenter.
    let pinyinSyllableTable: PinyinSyllableTable
    // The heavy Pinyin LM index (~55–80 MB), resident ONLY while at least one controller is in
    // Pinyin mode (ref-counted). Built lazily from data.txt on the first acquire.
    let pinyinIndexCache: RefCountedResource<TonelessLanguageModelIndex>

    // Simplex (速成) table: only needed once a controller actually selects 速成, so it's built
    // lazily on first access rather than eagerly at launch (building it arrays + sorts all
    // Cangjie entries). Guarded by a lock, mirroring RefCountedResource, since SharedResources
    // is prewarmed off-main and read from the input controller. Invalidated (not rebuilt) by
    // loadCangjieTables() on a 倉頡版本 change; the next access rebuilds for the new version.
    private let simplexLock = NSLock()
    private var cachedSimplexTable: SimplexTable?

    // Reverse index (char → 倉頡 code) for the 反查/拆碼提示 hint. Only read when
    // Preferences.codeHintEnabled is true (off by default), so it's built lazily on first
    // access rather than unconditionally at launch. Same locking approach as simplexTable.
    private let codeIndexLock = NSLock()
    private var cachedCodeIndex: CangjieCodeIndex?

    private init() {
        // Read data.txt to a String ONCE, split it into lines ONCE, then build both the LM
        // ranking and the associated phrases from that SAME line array (the previous code
        // split and tokenized data.txt twice — once per consumer).
        let dataText: String?
        if let url = Bundle.main.url(forResource: "data", withExtension: "txt") {
            dataText = try? String(contentsOf: url, encoding: .utf8)
        } else {
            dataText = nil
        }

        if let text = dataText {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            // Derive the character ranking straight from the lines WITHOUT building the full
            // LM: nothing at runtime needs the whole model, and streaming avoids the transient
            // ~55–80 MB table (lower launch peak memory + faster startup).
            characterRank = LanguageModel.characterScores(fromLines: lines)
            associatedPhrases = AssociatedPhrases(lines: lines)
        } else {
            NSLog("YahooKeyKey: data.txt missing; running with empty character ranking")
            characterRank = [:]
            NSLog("YahooKeyKey: data.txt missing; running with empty associated phrases")
            associatedPhrases = AssociatedPhrases(text: "")
        }

        // Placeholder empties satisfy Swift's two-phase init; the real table for the
        // selected version is loaded by loadCangjieTables() at the end of init (once every
        // stored property is set, so an instance method may be called).
        cangjieTable = CangjieTable(text: "")
        cangjieRank = characterRank

        // Load the bundled TC→SC table for the "輸出簡體字" toggle; fail safe to an empty
        // (pass-through) table if missing, so the toggle simply leaves text unchanged.
        let hanConvertTable: HanConvertTable
        if let url = Bundle.main.url(forResource: "opencc-TSCharacters", withExtension: "txt"),
           let loaded = try? HanConvertTable(contentsOf: url) {
            hanConvertTable = loaded
        } else {
            NSLog("YahooKeyKey: opencc-TSCharacters.txt missing; Simplified output disabled (pass-through)")
            hanConvertTable = HanConvertTable(text: "")
        }
        hanConvertFilter = HanConvertFilter(direction: .traditionalToSimplified, table: hanConvertTable)

        // Load the persisted user-learning store once (fail-safe to empty if absent/corrupt).
        userFreq = UserFrequency()

        // Pinyin syllable map: small, always loaded; fail-safe to empty if the resource is missing.
        if let url = Bundle.main.url(forResource: "pinyin-zhuyin", withExtension: "txt"),
           let loaded = try? PinyinSyllableTable(contentsOf: url) {
            pinyinSyllableTable = loaded
        } else {
            NSLog("YahooKeyKey: pinyin-zhuyin.txt missing; Pinyin input unavailable")
            pinyinSyllableTable = PinyinSyllableTable(text: "")
        }
        // Pinyin LM index: built lazily on first acquire (i.e. when a controller enters Pinyin),
        // by re-reading data.txt. Released when no controller holds Pinyin (see InputController).
        pinyinIndexCache = RefCountedResource {
            if let url = Bundle.main.url(forResource: "data", withExtension: "txt"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return TonelessLanguageModelIndex(text: text)
            }
            NSLog("YahooKeyKey: data.txt missing; Pinyin index empty")
            return TonelessLanguageModelIndex(text: "")
        }

        // All stored properties are now set: load the real Cangjie table for the selected
        // version. simplexTable/cangjieCodeIndex are lazy and build on first access.
        loadCangjieTables(version: Preferences.cangjieVersion)
    }

    // Load the Cangjie table and set the effective sort rank for the given version. 五代 uses
    // the bundled ibus table + LM ranking; 三代 uses the Yahoo! KeyKey table (cj-ext) with its
    // native line order (empty rank → the engines' stable sort preserves it).
    private func loadCangjieTables(version: CangjieVersion) {
        switch version {
        case .v5:
            cangjieTable = Self.loadCangjie(resource: "cangjie")
            cangjieRank = characterRank
        case .v3:
            cangjieTable = Self.loadCangjie(resource: "cangjie-yahoo")
            cangjieRank = [:]   // native table order
        }
        // Drop any cached simplexTable/cangjieCodeIndex: both are derived from cangjieTable
        // (or the version), so they must rebuild against the table just loaded. Rebuilding is
        // deferred to the next access rather than done eagerly here.
        simplexLock.lock()
        cachedSimplexTable = nil
        simplexLock.unlock()
        codeIndexLock.lock()
        cachedCodeIndex = nil
        codeIndexLock.unlock()
    }

    // Builds the Simplex table for `version`. 五代 derives it from the Cangjie table; 三代 loads
    // the Yahoo 速成 table's own native order directly, falling back to deriving from Cangjie if
    // simplex-yahoo.txt is missing.
    private static func buildSimplexTable(version: CangjieVersion, cangjieTable: CangjieTable) -> SimplexTable {
        switch version {
        case .v5:
            return SimplexTable(cangjie: cangjieTable)
        case .v3:
            if let url = Bundle.main.url(forResource: "simplex-yahoo", withExtension: "txt"),
               let loaded = try? SimplexTable(quickCodeContentsOf: url) {
                return loaded
            }
            NSLog("YahooKeyKey: simplex-yahoo.txt missing; deriving Simplex from Cangjie")
            return SimplexTable(cangjie: cangjieTable)
        }
    }

    // The Simplex (速成) table for the currently-selected 倉頡版本, built lazily on first access
    // and cached until the version changes (see loadCangjieTables). Thread-safe via simplexLock.
    var simplexTable: SimplexTable {
        simplexLock.lock()
        defer { simplexLock.unlock() }
        if let cached = cachedSimplexTable { return cached }
        let built = Self.buildSimplexTable(version: Preferences.cangjieVersion, cangjieTable: cangjieTable)
        cachedSimplexTable = built
        return built
    }

    // The reverse (char → 倉頡 code) index for the 反查/拆碼提示 hint, built lazily on first
    // access (it's only read when Preferences.codeHintEnabled is true) and cached until the
    // 倉頡版本 changes (see loadCangjieTables). Thread-safe via codeIndexLock.
    var cangjieCodeIndex: CangjieCodeIndex {
        codeIndexLock.lock()
        defer { codeIndexLock.unlock() }
        if let cached = cachedCodeIndex { return cached }
        let built = CangjieCodeIndex(table: cangjieTable)
        cachedCodeIndex = built
        return built
    }

    // The currently-resident Pinyin index (non-nil while a controller holds Pinyin), or an empty
    // index when none is resident. The Pinyin module's makeEngine reads this; the controller
    // manages acquire/release so the index is built only while Pinyin is actually in use.
    var pinyinIndexOrEmpty: TonelessLanguageModelIndex {
        pinyinIndexCache.current ?? TonelessLanguageModelIndex(text: "")
    }

    private static func loadCangjie(resource: String) -> CangjieTable {
        if let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
           let loaded = try? CangjieTable(contentsOf: url) {
            return loaded
        }
        NSLog("YahooKeyKey: \(resource).txt missing; running with empty Cangjie table")
        return CangjieTable(text: "")
    }

    // Rebuild the table/rank for the currently-selected version and notify controllers to
    // rebuild their live engines. Called when the user changes 倉頡版本 in Settings.
    func reloadCangjieTables() {
        loadCangjieTables(version: Preferences.cangjieVersion)
        NotificationCenter.default.post(name: .cangjieVersionChanged, object: nil)
    }
}

extension Notification.Name {
    // Posted after SharedResources rebuilds its Cangjie/Simplex tables for a new version.
    static let cangjieVersionChanged = Notification.Name("YahooKeyKeyCangjieVersionChanged")
}
