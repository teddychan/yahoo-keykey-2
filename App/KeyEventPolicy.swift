import AppKit

// Pure key-event routing decisions for InputController, kept free of IMK/engine state so they
// can be unit-tested. See InputController.handle(_:client:).
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
