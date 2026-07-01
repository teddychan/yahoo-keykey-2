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
    let hanConvertFilter: HanConvertFilter
    // One shared user-learning store across all controllers.
    let userFreq: UserFrequency

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
