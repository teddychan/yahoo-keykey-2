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
}

// Pure input-session-lifecycle decisions for InputController.
// See InputController.deactivateServer(_:).
enum SessionEndPolicy {
    /// What must happen to on-screen state when the input session ends (issue #70).
    enum Action: Equatable {
        /// Nothing composing and nothing suggested: no window is up, so there is nothing to do.
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
