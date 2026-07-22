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
}
