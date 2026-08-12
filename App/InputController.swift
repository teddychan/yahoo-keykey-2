import Cocoa
import InputMethodKit
import KeyKeyEngine
import DragonKit

@objc(InputController)
final class InputController: IMKInputController {
    // User learning: persisted selection-count store providing a live ranking bonus for
    // Cangjie/Simplex candidates, so committed characters surface higher next time.
    private let userFreq: UserFrequency
    // The gated learning bonus handed to the engines, and read again when ordering 聯想. Stored
    // rather than local to init because the association path needs the same closure — one gate,
    // so the setting cannot apply to composition candidates and not to suggestions.
    private let userRank: (Character) -> Double
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
    // Stroke confirmation for the active composition (issue #61). Only consulted when
    // Preferences.strokeConfirmationEnabled and the composition is auto-completed (速成, or 倉頡
    // with a `*` wildcard): until the user has pressed Space once, Space confirms the strokes
    // rather than paging. Reset alongside candidatePage whenever the composition itself changes.
    private var strokeConfirmed = false
    // Associated phrases (聯想) offered after committing a single character; empty when not in
    // association mode. Paged with `candidatePage`, shown in the same numbered candidate window.
    private var associations: [String] = []
    private static let pageSize = 9

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        // All heavy resources are loaded ONCE in SharedResources and shared across every
        // controller (IMK creates one InputController per client/app). These reads do not
        // copy: the engine tables are value-type structs and userFreq is a shared class.
        let shared = SharedResources.shared
        self.associatedPhrases = shared.associatedPhrases
        self.hanConvertFilter = shared.hanConvertFilter
        self.userFreq = shared.userFreq

        // Live user-learning bonus; the closure consults the shared store on every sort, so a
        // freshly-committed character promotes without rebuilding the engine. It also reads
        // Preferences on every call, so turning 依選字習慣調整候選字順序 off applies to the next
        // composition — no engine rebuild and no notification needed (issue #85).
        let userRank: (Character) -> Double = {
            AdaptiveCandidateOrder.bonus(for: $0,
                                         enabled: Preferences.adaptiveCandidateOrderEnabled,
                                         learned: shared.userFreq.bonus(for:))
        }
        self.userRank = userRank

        // The input-method registry. Each module's makeEngine reads the shared tables and
        // rank LIVE, so rebuilding an engine after a 倉頡版本 change picks up the new table
        // (三代 uses an empty cangjieRank → the table's native order is preserved).
        // To add a method: append a module here and an Info.plist input mode — nothing else.
        let modules = [
            InputMethodModule(modeSuffix: "Cangjie", displayName: "倉頡") {
                CangjieEngine(table: shared.cangjieTable, characterRank: shared.cangjieRank, userRank: userRank)
            },
            InputMethodModule(modeSuffix: "Simplex", displayName: "速成") {
                SimplexEngine(table: shared.simplexTable, characterRank: shared.cangjieRank, userRank: userRank)
            },
            InputMethodModule(modeSuffix: "Pinyin", displayName: "拼音") {
                // Cheap: reads the currently-acquired index (empty until a controller enters
                // Pinyin, which acquires in setValue before this closure runs). Registration
                // alone never builds the index.
                PinyinEngine(syllableTable: shared.pinyinSyllableTable,
                             index: shared.pinyinIndexOrEmpty, userRank: userRank)
            },
        ]
        self.modules = modules

        // Start on the default (first) module; IMK calls setValue(_:forTag:client:) with the
        // active input mode (and on every mode switch), which rebuilds the engine accordingly.
        self.currentModule = modules[0]
        self.engine = modules[0].makeEngine()
        super.init(server: server, delegate: delegate, client: inputClient)

        // Rebuild the live engine when the user changes 倉頡版本 in Settings, so the new
        // table/order applies immediately without re-selecting the input method.
        NotificationCenter.default.addObserver(self, selector: #selector(cangjieVersionChanged),
                                               name: .cangjieVersionChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // A controller can be torn down while in Pinyin; release its hold on the shared index.
        if currentModule.modeSuffix == "Pinyin" {
            SharedResources.shared.pinyinIndexCache.release()
        }
    }

    // Rebuild the active engine after a 倉頡版本 change. Mirrors the reset in
    // setValue(_:forTag:client:): commit any in-progress composition, then swap engines.
    @objc private func cangjieVersionChanged() {
        if let client = client() {
            _ = commitCurrent(to: client)
        } else {
            _ = engine.commit()
        }
        resetCompositionState()
        associations = []
        candidateWindow.hide()
        engine = currentModule.makeEngine()
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    // IMK input-menu (the menu shown in the input-method menu-bar item), organized to the
    // shared Dragon-App app-menu standard (liquid-glass-macos SKILL §5A) for an IME:
    //   1. quick-toggles zone (輸出簡體字 / 全形標點 / 聯想字詞), checkmarks reflect live prefs;
    //   2. any settings specific to the active input method (none for Cangjie/Simplex today);
    //   3. App menu grouping (§5A) — About Yahoo! KeyKey 2 · 檢查更新… · 設定….
    //      Candidate-window font size (候選字大小) is no longer offered here — the coarse
    //      小/中/大 choices were superseded by the fine-grained slider in 設定….
    //      解除安裝… is no longer offered here either — a rarely-used destructive action does
    //      not belong one click away in the everyday menu; it lives in 設定… as the
    //      Uninstall pane (AppMenuController.settingsPanes).
    //      Per §5A the IME app menu omits Quit (an IME is system-managed; quitting only makes
    //      typing unresponsive until macOS relaunches it). All items are TOP-LEVEL: the macOS
    //      input menu only routes top-level selections back to the controller, so a "⋯ Yahoo!
    //      KeyKey 2" submenu would render but never fire — the flat grouping is the correct
    //      IMK adaptation of the shared App-menu spec.
    override func menu() -> NSMenu! {
        let menu = NSMenu()

        // 1. Quick-toggles zone. Each flips its Preferences value live; checkmark reflects state.
        let convert = NSMenuItem(title: "輸出簡體字", action: #selector(toggleSimplified), keyEquivalent: "")
        convert.target = self
        convert.state = Preferences.outputSimplifiedEnabled ? .on : .off
        menu.addItem(convert)

        let fullWidth = NSMenuItem(title: "全形標點", action: #selector(toggleFullWidth), keyEquivalent: "")
        fullWidth.target = self
        fullWidth.state = Preferences.fullWidthPunctuationEnabled ? .on : .off
        menu.addItem(fullWidth)

        let associate = NSMenuItem(title: "聯想字詞", action: #selector(toggleAssociated), keyEquivalent: "")
        associate.target = self
        associate.state = Preferences.associatedPhrasesEnabled ? .on : .off
        menu.addItem(associate)

        let codeHint = NSMenuItem(title: "反查提示", action: #selector(toggleCodeHint), keyEquivalent: "")
        codeHint.target = self
        codeHint.state = Preferences.codeHintEnabled ? .on : .off
        menu.addItem(codeHint)

        // 2. Settings specific to the active input method (grouped with their method).
        // Empty for Cangjie/Simplex today; future methods supply items via methodMenuItems.
        let methodItems = currentModule.methodMenuItems()
        if !methodItems.isEmpty {
            menu.addItem(.separator())
            methodItems.forEach(menu.addItem)
        }

        // 3. App menu grouping (§5A): About · Check for updates · Settings.
        // Sourced from the shared DragonAppMenu — the one source of truth for the app-item
        // order, naming, and icons, so the Dragon apps can't drift the way hand-rolled NSMenus
        // did. includeQuit: false omits Quit by design (system-managed IME), and the kit drops
        // the divider with it, so these three items end the menu with nothing dangling.
        // items(_:) carries no leading separator either, so the one added below is still ours.
        // All items are top-level so IMK routes them.
        // Titles resolve via DragonKit's L() so they follow the picked language; IMK pulls
        // menu() fresh each time the input menu opens, so no cached menu to rebuild on change.
        // IMK calls menu() on the main thread, so entering the main actor to reach the
        // (main-actor) DragonAppMenu is safe.
        //
        // The items are RE-POINTED at real selectors below — do not "simplify" that back to
        // the kit's closures. The kit hands back items that dispatch through a private
        // NSMenuItem subclass whose own `target` is the item itself. That is correct AppKit,
        // but the macOS input menu does not use plain AppKit dispatch: it routes a top-level
        // selection back to the input controller and ignores each item's target — the very
        // routing that makes a submenu "render but never fire" (noted above). Under that model
        // the kit's action would be sent to InputController, which has no such method, and all
        // three items would silently do nothing. Re-pointing at @objc methods on self is
        // correct under BOTH dispatch models, so the items fire whichever one IMK really uses.
        menu.addItem(.separator())
        MainActor.assumeIsolated {
            // A Debug build passes onCheckForUpdates: nil, which drops the item from the input
            // menu entirely — the same mechanism a Sparkle-less Mac App Store build uses, and
            // what dragon-kit's own sample app does. MAC-APP-RELEASE-LIFECYCLE.md requires the
            // local build not to read the production appcast, and the SUEnableAutomaticChecks
            // false that build-app.sh stamps only covers SCHEDULED checks — this item is a
            // user-initiated one, sitting in the everyday menu. DragonUpdater builds Sparkle
            // lazily, so removing the item is also what keeps it uninitialized on the ordinary
            // path. An item left in place but made inert would read as a bug instead.
            let config = DragonAppMenu.Config(
                appName: AboutConfig.appName,
                onAbout: { [weak self] in self?.openAbout() },
                onSettings: { [weak self] in self?.openSettings() },
                onCheckForUpdates: DragonAbout.isDebugBuild()
                    ? nil
                    : { [weak self] in self?.checkForUpdates() },
                includeQuit: false
            )
            let items = DragonAppMenu.items(config)

            // Matched by TITLE, not by index: these titles are rebuilt from the very same L()
            // keys and format string the kit itself used, so a hit is exact — and if the kit
            // ever reorders or changes its item set, an unmatched item keeps the kit's own
            // dispatch instead of being silently wired to the wrong handler (a mis-wired
            // About-opens-Settings would be far worse than an item that doesn't fire).
            //
            // The *shape* of the kit's item set (exactly these three titles, canonical order,
            // no separators) is pinned by ConfigContentTests, so a kit change fails CI rather
            // than reaching a user. Nothing here traps: this app is linked without -O, so an
            // assert() would be live in the shipped build, and trapping inside an IME loaded
            // into every process breaks typing system-wide. Log and degrade, as App/ does
            // everywhere else.
            let selectorsByTitle: [String: Selector] = [
                String(format: L("DragonKit.menu.about"), AboutConfig.appName): #selector(openAbout),
                L("DragonKit.menu.checkForUpdates"): #selector(checkForUpdates),
                L("DragonKit.menu.settings"): #selector(openSettings),
            ]
            for item in items {
                guard let action = selectorsByTitle[item.title] else {
                    NSLog("YahooKeyKey: no selector for DragonAppMenu item \"\(item.title)\"; "
                          + "left on the kit's own dispatch and it may not fire")
                    menu.addItem(item)
                    continue
                }
                item.target = self
                item.action = action
                menu.addItem(item)
            }
        }
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

    @objc private func toggleCodeHint() {
        Preferences.codeHintEnabled.toggle()
    }

    // IMK invokes these input-menu selectors on the main thread, so entering the main actor
    // to reach the (main-actor) shared settings window controller is safe.
    @objc private func checkForUpdates() {
        MainActor.assumeIsolated { AppMenuController.shared.checkForUpdates() }
    }

    @objc private func openAbout() {
        MainActor.assumeIsolated { AppMenuController.shared.openAbout() }
    }

    @objc private func openSettings() {
        MainActor.assumeIsolated { AppMenuController.shared.openSettings() }
    }

    // IMK calls this when the user selects one of our input modes (Info.plist
    // ComponentInputModeDict). The value is the mode identifier string.
    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        let modeID = value as? String ?? ""
        // Look up the module whose suffix matches the IMK mode id; default to the first.
        let module = modules.first { modeID.hasSuffix(".\($0.modeSuffix)") } ?? modules[0]
        guard module.modeSuffix != currentModule.modeSuffix else { return }
        // Pinyin LM lifecycle: release the shared index when leaving Pinyin.
        if currentModule.modeSuffix == "Pinyin" {
            SharedResources.shared.pinyinIndexCache.release()
        }
        // Commit any in-progress composition so the rebuilt engine starts clean.
        if let client = sender as? IMKTextInput ?? client() {
            _ = commitCurrent(to: client)
        } else {
            _ = engine.commit()
        }
        resetCompositionState()
        associations = []
        candidateWindow.hide()
        currentModule = module
        // Acquire (and lazily build) the shared index when entering Pinyin, BEFORE makeEngine
        // reads it. Ref-counted, so concurrent Pinyin controllers share one resident index.
        if module.modeSuffix == "Pinyin" {
            SharedResources.shared.pinyinIndexCache.acquire()
        }
        engine = module.makeEngine()
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }

        // ⌘/⌃ combinations (⌘C copy, ⌘X cut, ⌘V paste, ⌃A …) are app/system shortcuts, never IME
        // input, so hand them straight back to the app. Without this the engine would treat ⌘C's
        // base letter "c" as the radical 金 and swallow the copy (issue #56); it also stops ⌘/⌃
        // with Space/Return/arrows from being eaten by the paging/commit branches below.
        if KeyEventPolicy.isSystemShortcut(event.modifierFlags) { return false }

        // 臨時英數 (quick English), classic Yahoo! KeyKey style: Shift + a letter (and no other
        // modifier) emits that English letter directly. Case follows CAPS LOCK, not Shift — Shift
        // is only the trigger — so it's lowercase with Caps off, uppercase with Caps on. Any
        // active composition/association is committed first; the next unshifted key resumes 中文.
        // ⌘/⌃/⌥ combinations are left alone so app shortcuts (⌘⇧S, etc.) still work.
        if event.modifierFlags.contains(.shift),
           event.modifierFlags.intersection([.control, .option, .command]).isEmpty,
           let raw = event.charactersIgnoringModifiers?.first, raw.isASCII, raw.isLetter {
            if !engine.composingText.isEmpty {
                _ = commitCurrent(to: client)
            } else if !associations.isEmpty {
                clearAssociations()
            }
            let caps = event.modifierFlags.contains(.capsLock)
            let letter = caps ? String(raw).uppercased() : String(raw).lowercased()
            client.insertText(letter, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            return true
        }

        // Association mode (聯想): after committing a single character we offer follow-on phrases.
        // The engine has no active composition here. Digits pick a phrase; arrows page; Esc
        // dismisses; any other key dismisses the suggestions and is then processed normally.
        if !associations.isEmpty {
            let count = associations.count
            let lastPage = (count - 1) / InputController.pageSize
            if event.keyCode == 53 { // Escape dismisses associations
                clearAssociations(); return true
            }
            // Arrows / Page Up / Page Down page through the suggestions; they are consumed even
            // at the first/last page, which they clamp to.
            switch KeyEventPolicy.pageStep(keyCode: event.keyCode, page: candidatePage,
                                           lastPage: lastPage) {
            case .move(let page): candidatePage = page; refresh(client); return true
            case .atEdge: return true
            case .notPaging: break
            }
            // SPACE pages to the next association page (wrapping last → first). On a
            // single page, fall through to dismiss the suggestions and insert a
            // literal space.
            if event.keyCode == 49,
               let page = KeyEventPolicy.spacePage(page: candidatePage, lastPage: lastPage) {
                candidatePage = page
                refresh(client)
                return true
            }
            // Which digit (if any) selects an associated phrase depends on the configured
            // trigger (issue #52). In .number mode a plain 1–9 picks (Shift+digit yields a
            // symbol that Int() rejects, so it falls through and dismisses, as before). In
            // .shift mode only Shift+1–9 with no ⌃⌥⌘ picks — matched by physical key code,
            // since `characters`/`charactersIgnoringModifiers` both apply Shift (7 → &) — and
            // a bare digit is NOT a pick, so it falls through, dismisses, and the idle engine
            // lets the app type the number.
            let selectionDigit = KeyEventPolicy.associationSelectionDigit(
                trigger: Preferences.associationSelectionTrigger,
                characters: event.characters,
                modifierFlags: event.modifierFlags,
                keyCode: event.keyCode)
            if let d = selectionDigit {
                if let index = KeyEventPolicy.candidateIndex(digit: d, page: candidatePage,
                                                            pageSize: InputController.pageSize,
                                                            count: count) {
                    // Associations are full phrases that START with the just-committed
                    // character (already in the document), so insert only the remainder
                    // after it (好 + association "好像" -> insert "像", giving 好像).
                    let suffix = KeyEventPolicy.associationSuffix(associations[index])
                    clearAssociations()
                    if !suffix.isEmpty {
                        client.insertText(applyHanConvert(suffix), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                        // Learn the continuation the user picked (係 from 關係), so it surfaces
                        // earlier both here and when typed by code. Same store, same gate.
                        if let ch = AdaptiveCandidateOrder.characterToLearn(
                            fromAssociationSuffix: suffix,
                            enabled: Preferences.adaptiveCandidateOrderEnabled) {
                            userFreq.record(ch)
                        }
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
            resetCompositionState()
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

        // Pinyin (phrase composition) owns key handling while composing: the engine holds an
        // editable multi-node buffer with a node cursor, so keys differ from Cangjie/Simplex.
        // Arrows move the cursor between nodes; digits 1–9 select the cursor node's candidate and
        // advance to the next node (committing the whole buffer once past the last node);
        // Space/Return commit the whole buffer; Backspace deletes; Esc discards.
        // Runs BEFORE the Cangjie/Simplex candidate block so those semantics don't apply.
        if let phrase = engine as? PhraseComposingEngine, !engine.composingText.isEmpty {
            switch event.keyCode {
            case 123, 126: // Left / Up → previous node
                _ = phrase.moveCursorLeft(); refresh(client); return true
            case 124, 125: // Right / Down → next node
                _ = phrase.moveCursorRight(); refresh(client); return true
            case 49, 36: // Space / Return → commit the whole composition
                return commitCurrent(to: client, offerAssociations: true)
            case 51: // Backspace → delete last letter, re-walk
                engine.backspace(); candidatePage = 0; refresh(client); return true
            case 53: // Escape → commit-then-discard (matches Cangjie/Simplex Esc)
                _ = engine.commit(); candidatePage = 0; refresh(client); return true
            default: break
            }
            // Digit 1–9: select the candidate for the cursor node, then advance to the next node —
            // or commit the whole buffer if this was the last node. So a single syllable commits
            // immediately (like 倉頡/速成), while multi-syllable phrases can be picked syllable by
            // syllable; Space still commits everything at once. (First page only in v1.)
            if let chars = event.characters, let d = Int(chars), (1...9).contains(d) {
                guard d - 1 < engine.candidates.count else { return true } // ignore out-of-range digit
                engine.selectCandidate(d - 1)
                if phrase.moveCursorRight() {
                    candidatePage = 0
                    refresh(client)
                    return true
                }
                return commitCurrent(to: client, offerAssociations: true)
            }
            // Letters / apostrophe extend the composition.
            if let ch = event.characters?.first, engine.handleKey(ch) {
                candidatePage = 0
                refresh(client)
                return true
            }
            // Anything else (e.g. punctuation) commits the buffer, then passes to the app.
            _ = commitCurrent(to: client)
            return false
        }

        // Cangjie/Simplex show candidates as soon as a code resolves, and their keys are a–z,
        // so digits 1–9 select directly within the current page, and arrows page through the
        // full candidate list.
        if !engine.candidates.isEmpty {
            let count = engine.candidates.count
            let lastPage = (count - 1) / InputController.pageSize
            // Arrows / Page Up / Page Down page through the candidates; they are consumed even at
            // the first/last page, which they clamp to.
            switch KeyEventPolicy.pageStep(keyCode: event.keyCode, page: candidatePage,
                                           lastPage: lastPage) {
            case .move(let page): candidatePage = page; refresh(client); return true
            case .atEdge: return true
            case .notPaging: break
            }
            // 以空白鍵確認字根 (issue #61): 速成 and 倉頡-with-`*` show candidates before the
            // code is finished, so the Space a 倉頡 typist presses out of muscle memory pages the
            // window (or commits) instead of confirming the strokes. When the option is on,
            // swallow the FIRST Space of such a composition as that confirmation — the page and
            // the marked text stay exactly as they are, and the next Space / 1–9 / arrow behaves
            // as it always has.
            if event.keyCode == 49,
               KeyEventPolicy.spaceConfirmsStroke(enabled: Preferences.strokeConfirmationEnabled,
                                                  autoCompletedCode: isAutoCompletedComposition,
                                                  alreadyConfirmed: strokeConfirmed) {
                strokeConfirmed = true
                return true
            }
            // SPACE pages to the next candidate page (wrapping last → first). On a
            // single page there is nothing to page, so fall through to the
            // commit-first-candidate-on-space behaviour below.
            if event.keyCode == 49,
               let page = KeyEventPolicy.spacePage(page: candidatePage, lastPage: lastPage) {
                candidatePage = page
                refresh(client)
                return true
            }
            if let d = KeyEventPolicy.selectionDigit(characters: event.characters) {
                if let index = KeyEventPolicy.candidateIndex(digit: d, page: candidatePage,
                                                            pageSize: InputController.pageSize,
                                                            count: count) {
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
            engine.backspace(); resetCompositionState(); refresh(client); return true
        case 53: // Escape cancels composition (commit-then-discard)
            guard !engine.composingText.isEmpty else { return false }
            _ = engine.commit(); resetCompositionState(); refresh(client); return true
        default: break
        }

        guard let ch = event.characters?.first else { return false }
        let consumed = engine.handleKey(ch)
        if consumed {
            // A new radical/key changes the candidate set; restart paging from page 0 and
            // require the stroke confirmation again (issue #61).
            resetCompositionState()
            refresh(client)
        }
        return consumed
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        _ = commitCurrent(to: client)
    }

    // IMK ends the input session when the client loses focus: the user switched app, clicked
    // another text field, or changed input source. Nothing handled that before, and IMK does not
    // call commitComposition for 聯想 (there is no marked text to commit), so a candidate or
    // association page left open stayed stranded on screen over the new app — visible even after
    // switching back to English, and unreachable because the keys that dismiss it now go to the
    // other app (issue #70). End the session with nothing on screen.
    override func deactivateServer(_ sender: Any!) {
        switch SessionEndPolicy.action(hasComposition: !engine.composingText.isEmpty,
                                       hasAssociations: !associations.isEmpty) {
        case .idle:
            break
        case .dismiss:
            clearAssociations()
        case .commit:
            // commitCurrent clears the marked text and hides the window; offerAssociations stays
            // false so a system-driven commit does not open a fresh 聯想 page as we leave.
            if let client = sender as? IMKTextInput ?? client() {
                _ = commitCurrent(to: client)
            } else {
                _ = engine.commit()
                resetCompositionState()
                clearAssociations()
            }
        }
        // Every branch above already hides the window for the state it handles, and refresh(_:)
        // only shows it when there are candidates to pick — so .idle really does mean nothing is
        // up. Hide anyway: this is the one place where being wrong strands a panel over another
        // app with no way to dismiss it, which is the whole of issue #70. Costs one orderOut.
        candidateWindow.hide()
    }

    @discardableResult
    private func commitCurrent(to client: IMKTextInput, offerAssociations: Bool = false) -> Bool {
        resetCompositionState()
        let text = engine.commit()
        if !text.isEmpty {
            client.insertText(applyHanConvert(text), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            // User learning: remember single-character selections so they rank higher next time.
            // Nothing is recorded while adaptive ordering is off — the setting pauses learning as
            // well as ignoring it, so a user who turned it off is not still being counted.
            if let ch = AdaptiveCandidateOrder.characterToLearn(
                fromCommitted: text, enabled: Preferences.adaptiveCandidateOrderEnabled) {
                userFreq.record(ch)
            }
        }
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        // After an explicit user commit of a single character, offer associated phrases (聯想).
        // System-driven commits (focus loss, mode switch) pass offerAssociations: false and stay idle.
        if offerAssociations, Preferences.associatedPhrasesEnabled, text.count == 1, let first = text.first {
            let phrases = associatedPhrases.associations(for: first, userRank: userRank)
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

    // Per-composition transient state: candidate paging and the issue-#61 stroke confirmation.
    // Called wherever the composition itself changes (new radical, backspace, cancel, commit,
    // engine swap) — NOT while merely paging, which must keep the confirmation.
    private func resetCompositionState() {
        candidatePage = 0
        strokeConfirmed = false
    }

    // Whether the active composition resolves to candidates before its code is complete: 速成
    // (a first+last-radical shorthand) or a 倉頡 code carrying the `*` wildcard. `*` has no
    // radical glyph, so composingText shows it literally and it is visible here. These are
    // exactly the compositions where Space is not a stroke confirmation today (issue #61);
    // plain 倉頡 types a determinate code, and 拼音 has its own key handling.
    private var isAutoCompletedComposition: Bool {
        engine is SimplexEngine || engine.composingText.contains("*")
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
            // In association mode, optionally show only the continuation after the committed
            // character (係／心／於) instead of the whole word (關係) — the classic Yahoo display.
            // Selection still indexes `associations` (unchanged) and inserts the dropFirst suffix.
            let continuationOnly = !associations.isEmpty && Preferences.associationContinuationOnly
            let slice = Array(cands[start..<min(start + size, cands.count)])
            // The string actually shown for each row (continuation-only drops the leading char).
            let shown = slice.map { continuationOnly ? String($0.dropFirst()) : $0 }
            // Convert only the displayed strings (WYSIWYG); selection still indexes `cands`.
            let page = shown.map { applyHanConvert($0) }
            // 反查/拆碼提示: show each candidate's code for the ACTIVE input method. In 拼音 the
            // candidates for the cursor node all share that node's typed reading, so show it
            // (e.g. "wo", "ni hao"); once committed there is no cursor, so 聯想 rows fall back to
            // each character's looked-up pinyin. In 倉頡/速成 show the 倉頡 code of each single-
            // character row, from the traditional (pre-conversion) glyph so it matches the code
            // you'd actually type. Empty array when the feature is off.
            let hints: [String?]
            if Preferences.codeHintEnabled {
                if let phrase = engine as? PhraseComposingEngine {
                    if let reading = phrase.cursorReading {
                        hints = shown.map { _ in reading }         // composing: shared node reading
                    } else {
                        hints = shown.map { pinyinReadingHint(for: $0) }  // 聯想: per-character pinyin
                    }
                } else {
                    let codeIndex = SharedResources.shared.cangjieCodeIndex
                    hints = shown.map { s -> String? in
                        guard s.count == 1, let ch = s.first else { return nil }
                        return codeIndex.codeGlyphs(for: ch)
                    }
                }
            } else {
                hints = []
            }
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            candidateWindow.show(page, page: candidatePage, pageCount: pageCount,
                                 fontSize: Preferences.candidateFontSize, hints: hints, near: rect)
        }
    }

    // The 拼音 hint for a committed candidate string (each character's looked-up pinyin,
    // space-joined, e.g. 覺得 → "jue de"). Returns nil unless EVERY character resolves, so a
    // partial reading is never shown. Used for 聯想 rows, which the user didn't type.
    private func pinyinReadingHint(for text: String) -> String? {
        let shared = SharedResources.shared
        let index = shared.pinyinIndexOrEmpty
        var readings: [String] = []
        for ch in text {
            guard let zhuyin = index.reading(forCharacter: ch),
                  let pinyin = shared.pinyinSyllableTable.pinyin(forZhuyin: zhuyin) else { return nil }
            readings.append(pinyin)
        }
        return readings.isEmpty ? nil : readings.joined(separator: " ")
    }
}
