import Cocoa
import InputMethodKit
import KeyKeyEngine

@objc(InputController)
final class InputController: IMKInputController {
    // User learning: persisted selection-count store providing a live ranking bonus for
    // Cangjie/Simplex candidates, so committed characters surface higher next time.
    private let userFreq: UserFrequency
    private let associatedPhrases: AssociatedPhrases
    // Traditional→Simplified character converter, applied only when Preferences.outputSimplifiedEnabled.
    private let hanConvertFilter: HanConvertFilter
    // Registry of available input methods (the first is the default). Adding a method is a
    // one-place change here plus an Info.plist input mode — see InputMethodModule.
    private let modules: [InputMethodModule]
    // The active module; selected by Info.plist mode id via setValue(_:forTag:client:).
    private var currentModule: InputMethodModule
    private var engine: InputEngine
    private let candidateWindow = CandidateWindow()
    // Current candidate page (9 per page) for the active composition; reused for association paging.
    private var candidatePage = 0
    // Associated phrases (聯想) offered after committing a single character; empty when not in
    // association mode. Paged with `candidatePage`, shown in the same numbered candidate window.
    private var associations: [String] = []
    private static let pageSize = 9

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        // All heavy resources are loaded ONCE in SharedResources and shared across every
        // controller (IMK creates one InputController per client/app). These reads do not
        // copy: the engine tables are value-type structs and userFreq is a shared class.
        let shared = SharedResources.shared
        let characterRank = shared.characterRank
        let cangjieTable = shared.cangjieTable
        let simplexTable = shared.simplexTable
        self.associatedPhrases = shared.associatedPhrases
        self.hanConvertFilter = shared.hanConvertFilter
        self.userFreq = shared.userFreq

        // Live user-learning bonus; the closure consults the shared store on every sort, so a
        // freshly-committed character promotes without rebuilding the engine.
        let userRank: (Character) -> Double = { shared.userFreq.bonus(for: $0) }

        // The input-method registry. Each module's makeEngine captures the shared tables/ranks.
        // To add a method: append a module here and an Info.plist input mode — nothing else.
        let modules = [
            InputMethodModule(modeSuffix: "Cangjie", displayName: "倉頡") {
                CangjieEngine(table: cangjieTable, characterRank: characterRank, userRank: userRank)
            },
            InputMethodModule(modeSuffix: "Simplex", displayName: "速成") {
                SimplexEngine(table: simplexTable, characterRank: characterRank, userRank: userRank)
            },
        ]
        self.modules = modules

        // Start on the default (first) module; IMK calls setValue(_:forTag:client:) with the
        // active input mode (and on every mode switch), which rebuilds the engine accordingly.
        self.currentModule = modules[0]
        self.engine = modules[0].makeEngine()
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    // IMK input-menu (the menu shown in the input-method menu-bar item), grouped to
    // mirror the original Yahoo! KeyKey settings layout:
    //   1. general toggles (聯想字詞 / 全形標點 / 輸出簡體字), checkmarks reflect live prefs;
    //   2. any settings specific to the active input method (none for Cangjie/Simplex today);
    //   3. 偏好設定… and 關於… (stateless "open window" actions, shared windows).
    override func menu() -> NSMenu! {
        let menu = NSMenu()

        // 1. General toggles. Each flips its Preferences value live; checkmark reflects state.
        let associate = NSMenuItem(title: "聯想字詞", action: #selector(toggleAssociated), keyEquivalent: "")
        associate.target = self
        associate.state = Preferences.associatedPhrasesEnabled ? .on : .off
        menu.addItem(associate)

        let fullWidth = NSMenuItem(title: "全形標點", action: #selector(toggleFullWidth), keyEquivalent: "")
        fullWidth.target = self
        fullWidth.state = Preferences.fullWidthPunctuationEnabled ? .on : .off
        menu.addItem(fullWidth)

        let convert = NSMenuItem(title: "輸出簡體字", action: #selector(toggleSimplified), keyEquivalent: "")
        convert.target = self
        convert.state = Preferences.outputSimplifiedEnabled ? .on : .off
        menu.addItem(convert)

        // Candidate-window font size (候選字大小). The macOS input menu routes only
        // TOP-LEVEL item selections back to the controller — items nested in a submenu
        // are shown but never fire — so the sizes are flat items under a disabled
        // header. The chosen size is read live by CandidateWindow on the next
        // composition; the checkmark marks the active size.
        let fontHeader = NSMenuItem(title: "候選字大小", action: nil, keyEquivalent: "")
        fontHeader.isEnabled = false
        menu.addItem(fontHeader)
        let currentFontSize = Preferences.candidateFontSize
        for (title, size, action) in Self.candidateFontSizeChoices {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = (currentFontSize == size) ? .on : .off
            menu.addItem(item)
        }

        // 2. Settings specific to the active input method (grouped with their method).
        // Empty for Cangjie/Simplex today; future methods supply items via methodMenuItems.
        let methodItems = currentModule.methodMenuItems()
        if !methodItems.isEmpty {
            menu.addItem(.separator())
            methodItems.forEach(menu.addItem)
        }

        // 3. Check for updates + About (stateless "open" actions).
        menu.addItem(.separator())
        let update = NSMenuItem(title: "檢查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        let about = NSMenuItem(title: "關於 Yahoo KeyKey 2…", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        return menu
    }

    @objc private func toggleAssociated() {
        Preferences.associatedPhrasesEnabled.toggle()
    }

    @objc private func toggleFullWidth() {
        Preferences.fullWidthPunctuationEnabled.toggle()
    }

    @objc private func toggleSimplified() {
        Preferences.outputSimplifiedEnabled.toggle()
    }

    // Named candidate-window font sizes (display title → point size → menu action),
    // all within the Preferences clamp (14–28); the default 18 is "中". Each size has
    // its own no-argument selector so it dispatches exactly like the toggles above —
    // the input menu's cross-process routing doesn't preserve a shared handler's tag.
    private static let candidateFontSizeChoices: [(title: String, size: CGFloat, action: Selector)] = [
        ("小", 14, #selector(setCandidateFontSizeSmall)),
        ("中", 18, #selector(setCandidateFontSizeMedium)),
        ("大", 24, #selector(setCandidateFontSizeLarge)),
    ]

    @objc private func setCandidateFontSizeSmall() { Preferences.candidateFontSize = 14 }
    @objc private func setCandidateFontSizeMedium() { Preferences.candidateFontSize = 18 }
    @objc private func setCandidateFontSizeLarge() { Preferences.candidateFontSize = 24 }

    @objc private func checkForUpdates() {
        Updater.shared.checkForUpdates()
    }

    @objc private func openAbout() {
        AboutWindowController.shared.show()
    }

    // IMK calls this when the user selects one of our input modes (Info.plist
    // ComponentInputModeDict). The value is the mode identifier string.
    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        let modeID = value as? String ?? ""
        // Look up the module whose suffix matches the IMK mode id; default to the first.
        let module = modules.first { modeID.hasSuffix(".\($0.modeSuffix)") } ?? modules[0]
        guard module.modeSuffix != currentModule.modeSuffix else { return }
        // Commit any in-progress composition so the rebuilt engine starts clean.
        if let client = sender as? IMKTextInput ?? client() {
            _ = commitCurrent(to: client)
        } else {
            _ = engine.commit()
        }
        candidatePage = 0
        associations = []
        candidateWindow.hide()
        currentModule = module
        engine = module.makeEngine()
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
            // SPACE pages to the next association page (wrapping last → first). On a
            // single page, fall through to dismiss the suggestions and insert a
            // literal space.
            if event.keyCode == 49, lastPage > 0 {
                candidatePage = (candidatePage + 1) % (lastPage + 1)
                refresh(client)
                return true
            }
            if let chars = event.characters, let d = Int(chars), (1...9).contains(d) {
                let index = candidatePage * InputController.pageSize + (d - 1)
                if index < count {
                    // Associations are full phrases that START with the just-committed
                    // character (already in the document), so insert only the remainder
                    // after it (好 + association "好像" -> insert "像", giving 好像).
                    let suffix = String(associations[index].dropFirst())
                    clearAssociations()
                    if !suffix.isEmpty {
                        client.insertText(applyHanConvert(suffix), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                    }
                    return true
                }
                return true // digit beyond this page: swallow, no insert
            }
            // Any other key: dismiss suggestions, then fall through to process the key normally.
            clearAssociations()
        }

        // `*` is a Cangjie wildcard radical. When idle, let the engine start a wildcard
        // composition before full-width punctuation would turn it into ＊. Simplex rejects
        // `*`, so handleKey returns false and it falls through to punctuation below.
        if event.characters?.first == "*", engine.composingText.isEmpty, engine.handleKey("*") {
            candidatePage = 0
            refresh(client)
            return true
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

        // Cangjie/Simplex show candidates as soon as a code resolves, and their keys are a–z,
        // so digits 1–9 select directly within the current page, and arrows page through the
        // full candidate list.
        if !engine.candidates.isEmpty {
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
            // SPACE pages to the next candidate page (wrapping last → first). On a
            // single page there is nothing to page, so fall through to the
            // commit-first-candidate-on-space behaviour below.
            if event.keyCode == 49, lastPage > 0 {
                candidatePage = (candidatePage + 1) % (lastPage + 1)
                refresh(client)
                return true
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

        // SPACE: with an active composition, commit the first candidate of the current page;
        // with nothing composing, let a literal space through.
        if event.keyCode == 49 { // Space
            if !engine.composingText.isEmpty {
                if !engine.candidates.isEmpty {
                    engine.selectCandidate(candidatePage * InputController.pageSize)
                }
                return commitCurrent(to: client, offerAssociations: true)
            } else {
                return false // nothing composing: pass a literal space to the app
            }
        }

        // Enter commits; Backspace deletes; Esc cancels; mapped keys feed the engine.
        switch event.keyCode {
        case 36: // Return
            guard !engine.composingText.isEmpty else { return false }
            // Cangjie/Simplex: commit the first candidate of the current page.
            if !engine.candidates.isEmpty {
                engine.selectCandidate(candidatePage * InputController.pageSize)
            }
            return commitCurrent(to: client, offerAssociations: true)
        case 51: // Delete/Backspace
            guard !engine.composingText.isEmpty else { return false }
            engine.backspace(); candidatePage = 0; refresh(client); return true
        case 53: // Escape cancels composition (commit-then-discard)
            guard !engine.composingText.isEmpty else { return false }
            _ = engine.commit(); candidatePage = 0; refresh(client); return true
        default: break
        }

        guard let ch = event.characters?.first else { return false }
        let consumed = engine.handleKey(ch)
        if consumed {
            // A new radical/key changes the candidate set; restart paging from page 0.
            candidatePage = 0
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
        candidatePage = 0
        let text = engine.commit()
        if !text.isEmpty {
            client.insertText(applyHanConvert(text), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            // User learning: remember single-character selections so they rank higher next time.
            if text.count == 1, let ch = text.first { userFreq.record(ch) }
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

    // Apply Traditional→Simplified conversion iff the user enabled "輸出簡體字" (read live).
    // Used for both committed text and candidate/association display so they stay WYSIWYG.
    private func applyHanConvert(_ text: String) -> String {
        Preferences.outputSimplifiedEnabled ? hanConvertFilter.convert(text) : text
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
        // Cangjie/Simplex always select by digit, so the numbered candidate window is shown
        // whenever there is something to pick.
        let cands = associations.isEmpty ? engine.candidates : associations
        if cands.isEmpty { candidateWindow.hide() }
        else {
            let size = InputController.pageSize
            let pageCount = (cands.count + size - 1) / size
            // Guard against a stale candidatePage pointing past the end (would trap on slice).
            if candidatePage * size >= cands.count { candidatePage = 0 }
            let start = candidatePage * size
            // Convert only the displayed strings (WYSIWYG); selection still indexes `cands`.
            let page = cands[start..<min(start + size, cands.count)].map(applyHanConvert)
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            candidateWindow.show(page, page: candidatePage, pageCount: pageCount,
                                 fontSize: Preferences.candidateFontSize, near: rect)
        }
    }
}
