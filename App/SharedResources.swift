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
    // Cangjie/Simplex tables and the effective sort rank depend on the selected Cangjie
    // version; rebuilt in place by reloadCangjieTables() when the user changes it.
    private(set) var cangjieTable: CangjieTable
    private(set) var simplexTable: SimplexTable
    // Single-char rank the engines sort by: the LM `characterRank` for 五代, or empty for
    // 三代 so the Yahoo table's native line order is preserved. User-learning applies on top.
    private(set) var cangjieRank: [Character: Double]
    // Reverse index (char → 倉頡 code) for the 反查/拆碼提示 hint; rebuilt with the tables so it
    // always matches the selected 倉頡版本.
    private(set) var cangjieCodeIndex: CangjieCodeIndex
    let hanConvertFilter: HanConvertFilter
    // One shared user-learning store across all controllers.
    let userFreq: UserFrequency
    // Small pinyin→zhuyin syllable map (eager; ~422 rows, tiny). Backs the Pinyin segmenter.
    let pinyinSyllableTable: PinyinSyllableTable
    // The heavy Pinyin LM index (~55–80 MB), resident ONLY while at least one controller is in
    // Pinyin mode (ref-counted). Built lazily from data.txt on the first acquire.
    let pinyinIndexCache: RefCountedResource<TonelessLanguageModelIndex>

    private init() {
        // Read data.txt to a String ONCE, then build both the LM and the associated
        // phrases from that same string (the previous code parsed data.txt twice).
        let dataText: String?
        if let url = Bundle.main.url(forResource: "data", withExtension: "txt") {
            dataText = try? String(contentsOf: url, encoding: .utf8)
        } else {
            dataText = nil
        }

        // Build the LM from data.txt ONLY to derive the character ranking, then let it go:
        // nothing at runtime needs the full model, so it is not retained (frees ~55–80 MB).
        let lm: LanguageModel
        if let text = dataText {
            lm = LanguageModel(text: text)
        } else {
            NSLog("YahooKeyKey: data.txt missing; running with empty LM")
            lm = LanguageModel(text: "# format org.openvanilla.mcbopomofo.sorted")
        }
        characterRank = lm.characterScores()

        // Build associated phrases from the SAME data.txt string; fail safe to empty if missing.
        if let text = dataText {
            associatedPhrases = AssociatedPhrases(text: text)
        } else {
            NSLog("YahooKeyKey: data.txt missing; running with empty associated phrases")
            associatedPhrases = AssociatedPhrases(text: "")
        }

        // Placeholder empties satisfy Swift's two-phase init; the real tables for the
        // selected version are loaded by loadCangjieTables() at the end of init (once every
        // stored property is set, so an instance method may be called).
        cangjieTable = CangjieTable(text: "")
        simplexTable = SimplexTable(cangjie: cangjieTable)
        cangjieRank = characterRank
        cangjieCodeIndex = CangjieCodeIndex(table: cangjieTable)

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

        // All stored properties are now set: load the real tables for the selected version.
        loadCangjieTables(version: Preferences.cangjieVersion)
    }

    // Load the Cangjie table, derive/load the Simplex table, and set the effective sort
    // rank for the given version. 五代 uses the bundled ibus table + LM ranking; 三代 uses
    // the Yahoo! KeyKey tables (cj-ext / simplex-ext) with their native line order (empty
    // rank → the engines' stable sort preserves it).
    private func loadCangjieTables(version: CangjieVersion) {
        switch version {
        case .v5:
            cangjieTable = Self.loadCangjie(resource: "cangjie")
            simplexTable = SimplexTable(cangjie: cangjieTable)
            cangjieRank = characterRank
        case .v3:
            cangjieTable = Self.loadCangjie(resource: "cangjie-yahoo")
            // Yahoo 速成 has its own native order; load it directly. Fail-safe: derive from
            // the Cangjie table if simplex-yahoo.txt is missing.
            if let url = Bundle.main.url(forResource: "simplex-yahoo", withExtension: "txt"),
               let loaded = try? SimplexTable(quickCodeContentsOf: url) {
                simplexTable = loaded
            } else {
                NSLog("YahooKeyKey: simplex-yahoo.txt missing; deriving Simplex from Cangjie")
                simplexTable = SimplexTable(cangjie: cangjieTable)
            }
            cangjieRank = [:]   // native table order
        }
        // Rebuild the reverse index from whichever table we just loaded.
        cangjieCodeIndex = CangjieCodeIndex(table: cangjieTable)
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

    // Rebuild the tables/rank for the currently-selected version and notify controllers to
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
