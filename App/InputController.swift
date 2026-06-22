import Cocoa
import InputMethodKit
import KeyKeyEngine

// Persisted phonetic-layout choice. Raw values are the keys stored in UserDefaults.
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

// Persisted input-method choice. Raw values are the keys stored in UserDefaults.
private enum InputMethodChoice: String {
    case smartPhonetic
    case plainPhonetic
    case cangjie

    // Cangjie has no Bopomofo keyboard layout; the layout submenu applies only to phonetic methods.
    var isPhonetic: Bool { self != .cangjie }
}

private let layoutDefaultsKey = "phoneticLayout"
private let methodDefaultsKey = "inputMethod"

@objc(InputController)
final class InputController: IMKInputController {
    private let lm: LanguageModel
    private let cangjieTable: CangjieTable
    private var method: InputMethodChoice
    private var layout: LayoutChoice
    private var engine: InputEngine
    private let candidateWindow = CandidateWindow()
    private var selecting = false

    // UserDefaults suited to the bundle id so the choice is shared across IMK clients.
    private let defaults = UserDefaults(suiteName: Bundle.main.bundleIdentifier) ?? .standard

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

        // self.defaults isn't usable yet (two-phase init: stored props before super.init),
        // so the UserDefaults suite is constructed inline here to read the persisted choices.
        let suite = UserDefaults(suiteName: Bundle.main.bundleIdentifier)
        let method = InputMethodChoice(rawValue: suite?.string(forKey: methodDefaultsKey) ?? "") ?? .smartPhonetic
        let layout = LayoutChoice(rawValue: suite?.string(forKey: layoutDefaultsKey) ?? "") ?? .standard
        self.method = method
        self.layout = layout
        self.engine = InputController.makeEngine(method: method, layout: layout, lm: lm, cangjieTable: cangjieTable)
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

    // IMK creates one controller per text session, but a menu pick updates only the
    // instance that owns the menu (plus shared UserDefaults). Re-read the persisted
    // choice when this session activates and before handling keys, rebuilding the engine
    // if it changed, so the selection applies to whichever instance handles typing.
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        syncFromDefaults()
    }

    private func syncFromDefaults() {
        let m = InputMethodChoice(rawValue: defaults.string(forKey: methodDefaultsKey) ?? "") ?? .smartPhonetic
        let l = LayoutChoice(rawValue: defaults.string(forKey: layoutDefaultsKey) ?? "") ?? .standard
        guard m != method || l != layout else { return }
        method = m
        layout = l
        selecting = false
        engine = InputController.makeEngine(method: m, layout: l, lm: lm, cangjieTable: cangjieTable)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }
        syncFromDefaults()   // pick up a method/layout change made via another session's menu

        // Selection mode (entered via Down): digits pick a candidate; Esc just closes the
        // picker and keeps the composition; any other key resumes normal composing.
        if selecting {
            if event.keyCode == 53 { // Escape exits selection without discarding composition
                selecting = false; refresh(client); return true
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
        // 1–9 select directly without first opening the picker. (Smart and Plain phonetic use
        // Down-then-digit, since digit keys are valid Bopomofo input there.)
        if method.usesDirectDigitSelect,
           let chars = event.characters, let d = Int(chars), (1...9).contains(d),
           d - 1 < engine.candidates.count {
            engine.selectCandidate(d - 1)
            return commitCurrent(to: client)
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
        if consumed { refresh(client) }
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

    // IMK input menu: pick the input method, then (for phonetic methods) the keyboard
    // layout. A check marks the active item; layout items are shown only when relevant.
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let currentMethod = InputMethodChoice(rawValue: defaults.string(forKey: methodDefaultsKey) ?? "") ?? .smartPhonetic
        let currentLayout = LayoutChoice(rawValue: defaults.string(forKey: layoutDefaultsKey) ?? "") ?? .standard

        for (choice, title) in [(InputMethodChoice.smartPhonetic, "Smart Phonetic (智慧注音)"),
                                (.plainPhonetic, "Plain Phonetic (傳統注音)"),
                                (.cangjie, "Cangjie (倉頡)")] {
            let item = NSMenuItem(title: title, action: #selector(switchMethod(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = (choice == currentMethod) ? .on : .off
            menu.addItem(item)
        }

        // Layout submenu applies only to phonetic methods; Cangjie has no Bopomofo layout.
        if currentMethod.isPhonetic {
            menu.addItem(.separator())
            for (choice, title) in [(LayoutChoice.standard, "Standard (大千)"), (.eten, "ETen (倚天)"),
                                    (.hsu, "Hsu (許氏)"), (.eten26, "ETen 26 (倚天26鍵)")] {
                let item = NSMenuItem(title: title, action: #selector(switchLayout(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = choice.rawValue
                item.state = (choice == currentLayout) ? .on : .off
                menu.addItem(item)
            }
        }
        return menu
    }

    @objc private func switchMethod(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let choice = InputMethodChoice(rawValue: raw), choice != method else { return }
        commitInProgress()
        defaults.set(raw, forKey: methodDefaultsKey)
        method = choice
        let layout = LayoutChoice(rawValue: defaults.string(forKey: layoutDefaultsKey) ?? "") ?? .standard
        engine = InputController.makeEngine(method: choice, layout: layout, lm: lm, cangjieTable: cangjieTable)
    }

    @objc private func switchLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let choice = LayoutChoice(rawValue: raw) else { return }
        commitInProgress()
        defaults.set(raw, forKey: layoutDefaultsKey)
        layout = choice
        // Rebuild the active phonetic engine on the new layout. (No-op shape for Cangjie,
        // but the layout submenu isn't shown for Cangjie so this stays phonetic-only.)
        engine = InputController.makeEngine(method: method, layout: choice, lm: lm, cangjieTable: cangjieTable)
    }

    // Commit any in-progress composition into the document so the rebuilt engine starts
    // clean without silently dropping the partial text. Used on method/layout switch.
    private func commitInProgress() {
        if let client = client() {
            _ = commitCurrent(to: client)
        } else {
            _ = engine.commit()
        }
        selecting = false
        candidateWindow.hide()
    }

    private func refresh(_ client: IMKTextInput) {
        let composing = engine.composingText
        client.setMarkedText(composing,
                             selectionRange: NSRange(location: composing.utf16.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        // Only show the numbered candidate window when number keys actually select:
        // in `selecting` mode (Smart/Plain, after Down) or for Cangjie (direct digit-select).
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

private extension InputMethodChoice {
    // Only Cangjie selects directly by digit: its keys are a–z, so digits are unambiguous
    // selectors. Smart and Plain phonetic use Down-then-digit, because in Bopomofo layouts
    // several digit keys ("1"=ㄅ, "2"=ㄉ, …) are valid input and must not be hijacked.
    var usesDirectDigitSelect: Bool { self == .cangjie }
}
