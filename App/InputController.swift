import Cocoa
import InputMethodKit
import KeyKeyEngine

// Phonetic keyboard layout. Layout selection UI is deferred to Preferences; the engine
// supports all four and defaults to Standard (大千).
private enum LayoutChoice: String {
    case standard
    case eten
    case hsu
    case eten26

    func makeLayout() -> PhoneticLayout {
        switch self {
        case .standard: return StandardLayout()
        case .eten: return EtenLayout()
        case .hsu: return HsuLayout()
        case .eten26: return Eten26Layout()
        }
    }
}

// The input method, selected by the user as an IMK input MODE (see Info.plist
// ComponentInputModeDict). IMK delivers the selection via setValue(_:forTag:client:).
private enum InputMethodChoice: String {
    case smartPhonetic
    case plainPhonetic
    case cangjie
    case simplex

    // Map an IMK input-mode identifier (…YahooKeyKey2.Cangjie etc.) to a method.
    // v1.0.0 exposes only Cangjie and Simplex; default to Cangjie.
    init(modeID: String) {
        if modeID.hasSuffix(".Simplex") { self = .simplex }
        else if modeID.hasSuffix(".PlainPhonetic") { self = .plainPhonetic }
        else if modeID.hasSuffix(".SmartPhonetic") { self = .smartPhonetic }
        else { self = .cangjie }
    }

    // Cangjie and Simplex select directly by digit: their keys are a–z, so digits are
    // unambiguous selectors. Phonetic methods use Down-then-digit, because in Bopomofo
    // layouts several digit keys ("1"=ㄅ, "2"=ㄉ, …) are valid input and must not be hijacked.
    var usesDirectDigitSelect: Bool { self == .cangjie || self == .simplex }
}

@objc(InputController)
final class InputController: IMKInputController {
    private let lm: LanguageModel
    private let characterRank: [Character: Double]
    private let associatedPhrases: AssociatedPhrases
    private let cangjieTable: CangjieTable
    private let simplexTable: SimplexTable
    private let layout: LayoutChoice = .standard
    private var method: InputMethodChoice = .cangjie
    private var engine: InputEngine
    private let candidateWindow = CandidateWindow()
    private var selecting = false
    // Current candidate page (9 per page) for the active composition; reused for association paging.
    private var candidatePage = 0
    // Associated phrases (聯想) offered after committing a single character; empty when not in
    // association mode. Paged with `candidatePage`, shown in the same numbered candidate window.
    private var associations: [String] = []
    private static let pageSize = 9

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        // Load the bundled LM once; fail safe to an empty model (no candidates) if missing.
        let lm: LanguageModel
        if let url = Bundle.main.url(forResource: "data", withExtension: "txt"),
           let loaded = try? LanguageModel(contentsOf: url) {
            lm = loaded
        } else {
            NSLog("YahooKeyKey: data.txt missing; running with empty LM")
            lm = LanguageModel(text: "# format org.openvanilla.mcbopomofo.sorted")
        }
        self.lm = lm

        // Rank single characters by LM score (higher = more common) so Cangjie/Simplex
        // wildcard matches surface common characters first. Computed once.
        let characterRank = lm.characterScores()
        self.characterRank = characterRank

        // Build associated phrases from the same bundled data.txt; fail safe to empty if missing.
        let associatedPhrases: AssociatedPhrases
        if let url = Bundle.main.url(forResource: "data", withExtension: "txt"),
           let loaded = try? AssociatedPhrases(contentsOf: url) {
            associatedPhrases = loaded
        } else {
            NSLog("YahooKeyKey: data.txt missing; running with empty associated phrases")
            associatedPhrases = AssociatedPhrases(text: "")
        }
        self.associatedPhrases = associatedPhrases

        // Load the bundled Cangjie table; fail safe to an empty table (no candidates) if missing.
        let cangjieTable: CangjieTable
        if let url = Bundle.main.url(forResource: "cangjie", withExtension: "txt"),
           let loaded = try? CangjieTable(contentsOf: url) {
            cangjieTable = loaded
        } else {
            NSLog("YahooKeyKey: cangjie.txt missing; running with empty Cangjie table")
            cangjieTable = CangjieTable(text: "")
        }
        self.cangjieTable = cangjieTable

        // Derive the Simplex table from the Cangjie table once (Simplex = first one/two
        // Cangjie radicals → all matching characters).
        let simplexTable = SimplexTable(cangjie: cangjieTable)
        self.simplexTable = simplexTable

        // Start on Cangjie; IMK calls setValue(_:forTag:client:) with the active input mode
        // (and on every mode switch), which rebuilds the engine accordingly.
        self.engine = InputController.makeEngine(method: .cangjie, layout: .standard,
                                                 lm: lm, characterRank: characterRank,
                                                 cangjieTable: cangjieTable,
                                                 simplexTable: simplexTable)
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    // Build the engine for the active method, wrapping in an adapter where the engine
    // surface doesn't already match the app-internal InputEngine protocol.
    private static func makeEngine(method: InputMethodChoice, layout: LayoutChoice,
                                   lm: LanguageModel, characterRank: [Character: Double],
                                   cangjieTable: CangjieTable,
                                   simplexTable: SimplexTable) -> InputEngine {
        switch method {
        case .smartPhonetic:
            return SmartPhoneticEngine(languageModel: lm, layout: layout.makeLayout())
        case .plainPhonetic:
            return PlainPhoneticEngineAdapter(PlainPhoneticEngine(languageModel: lm, layout: layout.makeLayout()))
        case .cangjie:
            return CangjieEngine(table: cangjieTable, characterRank: characterRank)
        case .simplex:
            return SimplexEngine(table: simplexTable, characterRank: characterRank)
        }
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    // IMK input-menu (the menu shown in the input-method menu-bar item). A single
    // "Preferences…" item opens the SHARED Preferences window — a stateless "open window"
    // action, independent of which controller instance receives it.
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let item = NSMenuItem(title: "偏好設定…", action: #selector(openPreferences), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    // IMK calls this when the user selects one of our input modes (Info.plist
    // ComponentInputModeDict). The value is the mode identifier string.
    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        let modeID = value as? String ?? ""
        let choice = InputMethodChoice(modeID: modeID)
        guard choice != method else { return }
        // Commit any in-progress composition so the rebuilt engine starts clean.
        if let client = sender as? IMKTextInput ?? client() {
            _ = commitCurrent(to: client)
        } else {
            _ = engine.commit()
        }
        selecting = false
        candidatePage = 0
        associations = []
        candidateWindow.hide()
        method = choice
        engine = InputController.makeEngine(method: choice, layout: layout, lm: lm,
                                            characterRank: characterRank,
                                            cangjieTable: cangjieTable, simplexTable: simplexTable)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }

        // Association mode (聯想): after committing a single character we offer follow-on phrases.
        // The engine has no active composition here. Digits pick a phrase; arrows page; Esc
        // dismisses; any other key dismisses the suggestions and is then processed normally.
        if !associations.isEmpty {
            let count = associations.count
            let lastPage = (count - 1) / InputController.pageSize
            switch event.keyCode {
            case 53: // Escape dismisses associations
                clearAssociations(); return true
            case 125, 124: // Down / Right arrow → next page
                if candidatePage < lastPage { candidatePage += 1; refresh(client) }
                return true
            case 126, 123: // Up / Left arrow → previous page
                if candidatePage > 0 { candidatePage -= 1; refresh(client) }
                return true
            default: break
            }
            if let chars = event.characters, let d = Int(chars), (1...9).contains(d) {
                let index = candidatePage * InputController.pageSize + (d - 1)
                if index < count {
                    let phrase = associations[index]
                    clearAssociations()
                    client.insertText(phrase, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                    return true
                }
                return true // digit beyond this page: swallow, no insert
            }
            // Any other key: dismiss suggestions, then fall through to process the key normally.
            clearAssociations()
        }

        // Full-width punctuation when idle: no active composition (and not in association mode,
        // already handled above). A mapped ASCII punctuation key inserts its full-width form.
        // Mid-composition keys are left to the engine below.
        if Preferences.fullWidthPunctuationEnabled,
           engine.composingText.isEmpty, let ch = event.characters?.first,
           let full = Punctuation.fullWidth(for: ch) {
            client.insertText(full, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            return true
        }

        // Selection mode (entered via Down): digits pick a candidate; Esc just closes the
        // picker and keeps the composition; any other key resumes normal composing.
        if selecting {
            if event.keyCode == 53 { // Escape exits selection without discarding composition
                selecting = false; refresh(client); return true
            }
            if event.keyCode == 49 { // Space confirms the current/top candidate
                if !engine.candidates.isEmpty { engine.selectCandidate(0) }
                return commitCurrent(to: client, offerAssociations: true)
            }
            if let chars = event.characters, let d = Int(chars), (1...9).contains(d),
               d - 1 < engine.candidates.count {
                engine.selectCandidate(d - 1)
                selecting = false
                return commitCurrent(to: client, offerAssociations: true)
            }
            selecting = false   // fall through to normal composing below
        }

        // Cangjie/Simplex show candidates as soon as a code resolves, and their keys are a–z,
        // so digits 1–9 select directly within the current page, and arrows page through the
        // full candidate list. (Phonetic methods use Down-then-digit, since digit keys are
        // valid Bopomofo input there.)
        if method.usesDirectDigitSelect, !engine.candidates.isEmpty {
            let count = engine.candidates.count
            let lastPage = (count - 1) / InputController.pageSize
            switch event.keyCode {
            case 125, 124: // Down / Right arrow → next page
                if candidatePage < lastPage { candidatePage += 1; refresh(client) }
                return true
            case 126, 123: // Up / Left arrow → previous page
                if candidatePage > 0 { candidatePage -= 1; refresh(client) }
                return true
            default: break
            }
            if let chars = event.characters, let d = Int(chars), (1...9).contains(d) {
                let index = candidatePage * InputController.pageSize + (d - 1)
                if index < count {
                    engine.selectCandidate(index)
                    return commitCurrent(to: client, offerAssociations: true)
                }
                return true // digit beyond this page's candidates: swallow, no insert
            }
        }

        // SPACE: while a syllable is still being composed (no tone yet), fall through so the
        // engine receives " " as tone 1 and finalizes it. Once a composition is finalized,
        // SPACE confirms/commits it; with nothing composing, let a literal space through.
        if event.keyCode == 49 { // Space
            if engine.isComposingSyllable {
                // fall through to engine.handleKey(" ") below to finalize as tone 1
            } else if !engine.composingText.isEmpty {
                if method == .smartPhonetic {
                    return commitCurrent(to: client, offerAssociations: true)
                } else if method.usesDirectDigitSelect { // .cangjie / .simplex: commit first of current page
                    if !engine.candidates.isEmpty {
                        engine.selectCandidate(candidatePage * InputController.pageSize)
                    }
                    return commitCurrent(to: client, offerAssociations: true)
                } else { // .plainPhonetic: commit the top candidate
                    if !engine.candidates.isEmpty { engine.selectCandidate(0) }
                    return commitCurrent(to: client, offerAssociations: true)
                }
            } else {
                return false // nothing composing: pass a literal space to the app
            }
        }

        // Enter commits; Backspace deletes; Esc cancels; Down opens selection; mapped keys feed the engine.
        switch event.keyCode {
        case 36: // Return
            guard !engine.composingText.isEmpty else { return false }
            // Cangjie/Simplex: commit the first candidate of the current page.
            if method.usesDirectDigitSelect, !engine.candidates.isEmpty {
                engine.selectCandidate(candidatePage * InputController.pageSize)
            }
            return commitCurrent(to: client, offerAssociations: true)
        case 51: // Delete/Backspace
            guard !engine.composingText.isEmpty else { return false }
            engine.backspace(); candidatePage = 0; refresh(client); return true
        case 53: // Escape cancels composition (commit-then-discard)
            guard !engine.composingText.isEmpty else { return false }
            _ = engine.commit(); candidatePage = 0; refresh(client); return true
        case 125: // Down arrow opens candidate selection
            guard !engine.composingText.isEmpty, !engine.candidates.isEmpty else { return false }
            selecting = true; refresh(client); return true
        default: break
        }

        guard let ch = event.characters?.first else { return false }
        let consumed = engine.handleKey(ch)
        if consumed {
            // A new radical/key changes the candidate set; restart paging from page 0.
            candidatePage = 0
            // Plain Phonetic: as soon as a syllable completes, show its numbered candidates
            // (incl. after space=tone 1) so digits 1–9 select. Down still works.
            if method == .plainPhonetic, !engine.candidates.isEmpty { selecting = true }
            refresh(client)
        }
        return consumed
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        _ = commitCurrent(to: client)
    }

    @discardableResult
    private func commitCurrent(to client: IMKTextInput, offerAssociations: Bool = false) -> Bool {
        selecting = false
        candidatePage = 0
        let text = engine.commit()
        if !text.isEmpty {
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        // After an explicit user commit of a single character, offer associated phrases (聯想).
        // System-driven commits (focus loss, mode switch) pass offerAssociations: false and stay idle.
        if offerAssociations, Preferences.associatedPhrasesEnabled, text.count == 1, let first = text.first {
            let phrases = associatedPhrases.associations(for: first)
            if !phrases.isEmpty {
                associations = phrases
                candidatePage = 0
                refresh(client)
                return true
            }
        }
        associations = []
        candidateWindow.hide()
        return true
    }

    // Leave association mode: drop the suggestions, reset paging, hide the candidate window.
    private func clearAssociations() {
        associations = []
        candidatePage = 0
        candidateWindow.hide()
    }

    private func refresh(_ client: IMKTextInput) {
        let composing = engine.composingText
        client.setMarkedText(composing,
                             selectionRange: NSRange(location: composing.utf16.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        // In association mode show the suggested phrases (paged); otherwise show engine candidates.
        // Only show the numbered candidate window when number keys actually select:
        // in `selecting` mode (phonetic, after Down) or for Cangjie (direct digit-select).
        // Otherwise the list would imply number-select while digits are still Bopomofo input.
        let cands = associations.isEmpty ? engine.candidates : associations
        let numbersSelect = !associations.isEmpty || selecting || method.usesDirectDigitSelect
        if cands.isEmpty || !numbersSelect { candidateWindow.hide() }
        else {
            let size = InputController.pageSize
            let pageCount = (cands.count + size - 1) / size
            // Guard against a stale candidatePage pointing past the end (would trap on slice).
            if candidatePage * size >= cands.count { candidatePage = 0 }
            let start = candidatePage * size
            let page = Array(cands[start..<min(start + size, cands.count)])
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            candidateWindow.show(page, page: candidatePage, pageCount: pageCount,
                                 fontSize: Preferences.candidateFontSize, near: rect.origin)
        }
    }
}
