import Cocoa
import KeyKeyEngine

// Process-wide, load-once store for the heavy IME resources. IMK creates one
// InputController per client (per app), so loading these per instance duplicated
// ~55–80 MB across every app. This singleton loads each resource exactly once and
// every controller reads from it; the engine types are value-type structs (and
// UserFrequency is a shared class), so reads do not copy.
final class SharedResources {
    static let shared = SharedResources()

    let lm: LanguageModel
    // Single-character LM ranking (higher = more common), used so Cangjie/Simplex
    // wildcard matches surface common characters first. Computed once.
    let characterRank: [Character: Double]
    let associatedPhrases: AssociatedPhrases
    let cangjieTable: CangjieTable
    let simplexTable: SimplexTable
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

        // Load the bundled LM once; fail safe to an empty model (no candidates) if missing.
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

        // Load the bundled Cangjie table; fail safe to an empty table (no candidates) if missing.
        if let url = Bundle.main.url(forResource: "cangjie", withExtension: "txt"),
           let loaded = try? CangjieTable(contentsOf: url) {
            cangjieTable = loaded
        } else {
            NSLog("YahooKeyKey: cangjie.txt missing; running with empty Cangjie table")
            cangjieTable = CangjieTable(text: "")
        }

        // Derive the Simplex table from the Cangjie table once (Simplex = first one/two
        // Cangjie radicals → all matching characters).
        simplexTable = SimplexTable(cangjie: cangjieTable)

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
    }
}
