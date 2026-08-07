import AppKit

// Pure decisions for InputController — key-event routing and input-session lifecycle — kept free
// of IMK/engine state so they can be unit-tested. Both policies live in this one file because
// tools/build-app.sh compiles an explicit list of App/ sources; a separate file would need to be
// added there too.
// See InputController.handle(_:client:).
enum KeyEventPolicy {
    /// Whether a keyDown carrying these modifiers is an app/system shortcut the IME must not
    /// touch. ⌘ and ⌃ combinations (⌘C copy, ⌘X cut, ⌘V paste, ⌃A line-start, …) belong to the
    /// app: for a ⌘ combination `NSEvent.characters` is the plain base letter, so without this
    /// guard the engine would treat ⌘C as the radical "c" and swallow the copy (issue #56).
    /// ⇧ (臨時英數) and ⌥ stay with the IME — ⌥ combos produce non-a–z characters the engine
    /// already rejects.
    static func isSystemShortcut(_ flags: NSEvent.ModifierFlags) -> Bool {
        !flags.intersection([.command, .control]).isEmpty
    }

    /// Whether this Space press should only CONFIRM the typed strokes instead of paging the
    /// candidate window or committing (issue #61).
    ///
    /// 速成 and 倉頡-with-`*` resolve to candidates before the code is finished, so the Space a
    /// 倉頡 typist presses out of muscle memory ("type strokes → Space") lands in the candidate
    /// window and flips to page 2. With the stroke-confirmation option on, the FIRST Space of
    /// such a composition is swallowed as that confirmation; every later Space — and every plain
    /// 倉頡 or 拼音 composition — behaves exactly as before.
    ///
    /// Callers apply this only while candidates are on screen; with none there is no page to
    /// flip and no character to pick, so Space keeps its existing commit/pass-through meaning.
    static func spaceConfirmsStroke(enabled: Bool, autoCompletedCode: Bool,
                                    alreadyConfirmed: Bool) -> Bool {
        enabled && autoCompletedCode && !alreadyConfirmed
    }

    // MARK: - The numbered candidate window (candidates and 聯想 page identically)

    /// The 1–9 selection digit a key event's `characters` denotes, or nil for anything else. Reads
    /// `characters`, so a SHIFTED number key — which reports its symbol (7 → &) — is deliberately
    /// not a selection.
    static func selectionDigit(characters: String?) -> Int? {
        guard let characters, let digit = Int(characters), (1...9).contains(digit) else { return nil }
        return digit
    }

    // Number-row key codes → digit (1–9). Layout-stable and Shift-independent, unlike
    // `characters`/`charactersIgnoringModifiers`, which return the shifted symbol (7 → &).
    // Used to detect Shift+digit for associated-phrase selection (issue #52).
    private static let numberRowDigits: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
    ]

    /// Which digit (if any) selects an associated phrase, given the configured trigger (issue #52).
    /// In `.number` mode a plain 1–9 picks (Shift+digit yields a symbol that Int() rejects, so it
    /// falls through and dismisses, as before). In `.shift` mode only Shift+1–9 with no ⌃⌥⌘ picks —
    /// matched by physical key code, since `characters`/`charactersIgnoringModifiers` both apply
    /// Shift (7 → &) — and a bare digit is NOT a pick, so it falls through, dismisses, and the idle
    /// engine lets the app type the number.
    static func associationSelectionDigit(trigger: AssociationTrigger, characters: String?,
                                          modifierFlags: NSEvent.ModifierFlags,
                                          keyCode: UInt16) -> Int? {
        switch trigger {
        case .number:
            return selectionDigit(characters: characters)
        case .shift:
            guard modifierFlags.contains(.shift),
                  modifierFlags.intersection([.control, .option, .command]).isEmpty else { return nil }
            return numberRowDigits[keyCode]
        }
    }

    /// The index into the FULL list that selection digit `digit` picks on `page`, or nil when that
    /// row falls past the end of the list. A nil is not a key the caller should pass on: the last
    /// page is rarely full, and a digit pressed on an empty row is swallowed so no stray number
    /// leaks into the document.
    static func candidateIndex(digit: Int, page: Int, pageSize: Int, count: Int) -> Int? {
        let index = page * pageSize + (digit - 1)
        return index < count ? index : nil
    }

    /// What an arrow / Page Up / Page Down key does to the shown page.
    enum PageStep: Equatable {
        /// Not a paging key: the caller carries on with its other branches.
        case notPaging
        /// A paging key on the first (or last) page. Arrows clamp rather than wrap, but the key is
        /// still consumed, leaving the page and the marked text exactly as they are.
        case atEdge
        /// Show this page instead, and redraw.
        case move(to: Int)
    }

    /// The paging step for a key pressed while the numbered window is up.
    static func pageStep(keyCode: UInt16, page: Int, lastPage: Int) -> PageStep {
        switch keyCode {
        case 125, 124, 121: // Down / Right arrow / Page Down → next page
            return page < lastPage ? .move(to: page + 1) : .atEdge
        case 126, 123, 116: // Up / Left arrow / Page Up → previous page
            return page > 0 ? .move(to: page - 1) : .atEdge
        default:
            return .notPaging
        }
    }

    /// The page SPACE moves to, wrapping last → first — or nil on a single page, where there is
    /// nothing to page and Space keeps its other meaning (dismiss the 聯想 suggestions and insert a
    /// literal space; with candidates up, commit the first one).
    static func spacePage(page: Int, lastPage: Int) -> Int? {
        guard lastPage > 0 else { return nil }
        return (page + 1) % (lastPage + 1)
    }

    /// The text a picked association inserts. Associations are full phrases that START with the
    /// just-committed character (already in the document), so only the remainder after it is
    /// inserted (好 + association "好像" -> insert "像", giving 好像). Empty for a one-character
    /// phrase, which inserts nothing.
    static func associationSuffix(_ phrase: String) -> String {
        String(phrase.dropFirst())
    }
}

// Pure input-session-lifecycle decisions for InputController.
// See InputController.deactivateServer(_:).
enum SessionEndPolicy {
    /// What must happen to the session's own state when it ends (issue #70). The caller hides
    /// the candidate window in every case; this decides only what to do with composition and
    /// suggestions.
    enum Action: Equatable {
        /// Nothing composing and nothing suggested: no state to clear.
        case idle
        /// 聯想 suggestions are showing with no composition. They are offers the user never typed,
        /// so they are dropped without inserting anything.
        case dismiss
        /// A composition is in progress: commit it, which also clears the marked text.
        case commit
    }

    /// The action for a session that is ending because the client lost focus — the user switched
    /// app, clicked another text field, or changed input source.
    ///
    /// A composition takes precedence over suggestions: it is the state holding text the user
    /// actually typed, so it must be committed rather than silently discarded.
    static func action(hasComposition: Bool, hasAssociations: Bool) -> Action {
        if hasComposition { return .commit }
        return hasAssociations ? .dismiss : .idle
    }
}
