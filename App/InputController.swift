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

private let layoutDefaultsKey = "phoneticLayout"

@objc(InputController)
final class InputController: IMKInputController {
    private let lm: LanguageModel
    private var engine: SmartPhoneticEngine
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
        // self.defaults isn't usable yet (two-phase init: stored props before super.init),
        // so the UserDefaults suite is constructed inline here to read the layout choice.
        let choice = LayoutChoice(rawValue: UserDefaults(suiteName: Bundle.main.bundleIdentifier)?
            .string(forKey: layoutDefaultsKey) ?? "") ?? .standard
        engine = SmartPhoneticEngine(languageModel: lm, layout: choice.makeLayout())
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }

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

    // IMK input menu: let the user pick the phonetic keyboard layout. A check marks the active one.
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let current = LayoutChoice(rawValue: defaults.string(forKey: layoutDefaultsKey) ?? "") ?? .standard
        for (choice, title) in [(LayoutChoice.standard, "Standard (大千)"), (.eten, "ETen (倚天)"),
                                (.hsu, "Hsu (許氏)"), (.eten26, "ETen 26 (倚天26鍵)")] {
            let item = NSMenuItem(title: title, action: #selector(switchLayout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = (choice == current) ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func switchLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let choice = LayoutChoice(rawValue: raw) else { return }
        // Commit any in-progress composition into the document so the rebuilt
        // engine starts clean without silently dropping the partial text.
        if let client = client() {
            _ = commitCurrent(to: client)
        } else {
            _ = engine.commit()
        }
        selecting = false
        candidateWindow.hide()
        defaults.set(raw, forKey: layoutDefaultsKey)
        engine = SmartPhoneticEngine(languageModel: lm, layout: choice.makeLayout())
    }

    private func refresh(_ client: IMKTextInput) {
        let composing = engine.composingText
        client.setMarkedText(composing,
                             selectionRange: NSRange(location: composing.utf16.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        let cands = engine.candidates
        if cands.isEmpty { candidateWindow.hide() }
        else {
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            candidateWindow.show(cands, near: rect.origin)
        }
    }
}
