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

    // Map an IMK input-mode identifier (…YahooKeyKey2.Cangjie etc.) to a method.
    init(modeID: String) {
        if modeID.hasSuffix(".Cangjie") { self = .cangjie }
        else if modeID.hasSuffix(".PlainPhonetic") { self = .plainPhonetic }
        else { self = .smartPhonetic }
    }

    // Only Cangjie selects directly by digit: its keys are a–z, so digits are unambiguous
    // selectors. Phonetic methods use Down-then-digit, because in Bopomofo layouts several
    // digit keys ("1"=ㄅ, "2"=ㄉ, …) are valid input and must not be hijacked.
    var usesDirectDigitSelect: Bool { self == .cangjie }
}

@objc(InputController)
final class InputController: IMKInputController {
    private let lm: LanguageModel
    private let cangjieTable: CangjieTable
    private let layout: LayoutChoice = .standard
    private var method: InputMethodChoice = .smartPhonetic
    private var engine: InputEngine
    private let candidateWindow = CandidateWindow()
    private var selecting = false

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

        // Start on Smart Phonetic; IMK calls setValue(_:forTag:client:) with the active
        // input mode (and on every mode switch), which rebuilds the engine accordingly.
        self.engine = InputController.makeEngine(method: .smartPhonetic, layout: .standard,
                                                 lm: lm, cangjieTable: cangjieTable)
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    // Build the engine for the active method, wrapping in an adapter where the engine
    // surface doesn't already match the app-internal InputEngine protocol.
    private static func makeEngine(method: InputMethodChoice, layout: LayoutChoice,
                                   lm: LanguageModel, cangjieTable: CangjieTable) -> InputEngine {
        switch method {
        case .smartPhonetic:
            return SmartPhoneticEngine(languageModel: lm, layout: layout.makeLayout())
        case .plainPhonetic:
            return PlainPhoneticEngineAdapter(PlainPhoneticEngine(languageModel: lm, layout: layout.makeLayout()))
        case .cangjie:
            return CangjieEngine(table: cangjieTable)
        }
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    // IMK calls this when the user selects one of our input modes (Info.plist
    // ComponentInputModeDict). The value is the mode identifier string.
    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        let modeID = value as? String ?? ""
        let choice = InputMethodChoice(modeID: modeID)
        guard choice != method else { return }
        // Commit any in-progress composition so the rebuilt engine starts clean.
        if let client = sender as? IMKTextInput ?? client() as? IMKTextInput {
            _ = commitCurrent(to: client)
        } else {
            _ = engine.commit()
        }
        selecting = false
        candidateWindow.hide()
        method = choice
        engine = InputController.makeEngine(method: choice, layout: layout, lm: lm, cangjieTable: cangjieTable)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }

        // Selection mode (entered via Down): digits pick a candidate; Esc just closes the
        // picker and keeps the composition; any other key resumes normal composing.
        if selecting {
            if event.keyCode == 53 { // Escape exits selection without discarding composition
                selecting = false; refresh(client); return true
            }
            if event.keyCode == 49 { // Space confirms the current/top candidate
                if !engine.candidates.isEmpty { engine.selectCandidate(0) }
                return commitCurrent(to: client)
            }
            if let chars = event.characters, let d = Int(chars), (1...9).contains(d),
               d - 1 < engine.candidates.count {
                engine.selectCandidate(d - 1)
                selecting = false
                return commitCurrent(to: client)
            }
            selecting = false   // fall through to normal composing below
        }

        // Cangjie shows candidates as soon as a code resolves, and its keys are a–z, so digits
        // 1–9 select directly without first opening the picker. (Phonetic methods use
        // Down-then-digit, since digit keys are valid Bopomofo input there.)
        if method.usesDirectDigitSelect,
           let chars = event.characters, let d = Int(chars), (1...9).contains(d),
           d - 1 < engine.candidates.count {
            engine.selectCandidate(d - 1)
            return commitCurrent(to: client)
        }

        // SPACE: while a syllable is still being composed (no tone yet), fall through so the
        // engine receives " " as tone 1 and finalizes it. Once a composition is finalized,
        // SPACE confirms/commits it; with nothing composing, let a literal space through.
        if event.keyCode == 49 { // Space
            if engine.isComposingSyllable {
                // fall through to engine.handleKey(" ") below to finalize as tone 1
            } else if !engine.composingText.isEmpty {
                if method == .smartPhonetic {
                    return commitCurrent(to: client)
                } else { // .plainPhonetic / .cangjie: commit the top candidate
                    if !engine.candidates.isEmpty { engine.selectCandidate(0) }
                    return commitCurrent(to: client)
                }
            } else {
                return false // nothing composing: pass a literal space to the app
            }
        }

        // Enter commits; Backspace deletes; Esc cancels; Down opens selection; mapped keys feed the engine.
        switch event.keyCode {
        case 36: // Return
            guard !engine.composingText.isEmpty else { return false }
            return commitCurrent(to: client)
        case 51: // Delete/Backspace
            guard !engine.composingText.isEmpty else { return false }
            engine.backspace(); refresh(client); return true
        case 53: // Escape cancels composition (commit-then-discard)
            guard !engine.composingText.isEmpty else { return false }
            _ = engine.commit(); refresh(client); return true
        case 125: // Down arrow opens candidate selection
            guard !engine.composingText.isEmpty, !engine.candidates.isEmpty else { return false }
            selecting = true; refresh(client); return true
        default: break
        }

        guard let ch = event.characters?.first else { return false }
        let consumed = engine.handleKey(ch)
        if consumed {
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
    private func commitCurrent(to client: IMKTextInput) -> Bool {
        selecting = false
        let text = engine.commit()
        if !text.isEmpty {
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        candidateWindow.hide()
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        return true
    }

    private func refresh(_ client: IMKTextInput) {
        let composing = engine.composingText
        client.setMarkedText(composing,
                             selectionRange: NSRange(location: composing.utf16.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        // Only show the numbered candidate window when number keys actually select:
        // in `selecting` mode (phonetic, after Down) or for Cangjie (direct digit-select).
        // Otherwise the list would imply number-select while digits are still Bopomofo input.
        let cands = engine.candidates
        let numbersSelect = selecting || method.usesDirectDigitSelect
        if cands.isEmpty || !numbersSelect { candidateWindow.hide() }
        else {
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            candidateWindow.show(cands, near: rect.origin)
        }
    }
}
