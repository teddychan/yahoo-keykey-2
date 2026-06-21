import Cocoa
import InputMethodKit
import KeyKeyEngine

@objc(InputController)
final class InputController: IMKInputController {
    private let engine: SmartPhoneticEngine
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
        engine = SmartPhoneticEngine(languageModel: lm)
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }

        // Enter commits; Backspace deletes; Esc cancels; Down opens selection; mapped keys feed the engine.
        switch event.keyCode {
        case 36: // Return
            guard !engine.composingText.isEmpty else { return false }
            return commitCurrent(to: client)
        case 51: // Delete/Backspace
            guard !engine.composingText.isEmpty else { return false }
            engine.backspace(); refresh(client); return true
        case 53: // Escape
            guard !engine.composingText.isEmpty else { return false }
            selecting = false
            _ = engine.commit(); refresh(client); return true // cancel composition (commit-then-discard)
        case 125: // Down arrow opens candidate selection
            guard !engine.composingText.isEmpty, !engine.candidates.isEmpty else { return false }
            selecting = true; refresh(client); return true
        default: break
        }

        if selecting {
            if let chars = event.characters, let d = Int(chars), (1...9).contains(d),
               d - 1 < engine.candidates.count {
                engine.selectCandidate(d - 1)
                selecting = false
                return commitCurrent(to: client)
            }
            if event.keyCode == 53 { selecting = false; refresh(client); return true } // Esc exits selection
            // any other key: leave selection mode and fall through to normal composing
            selecting = false
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
