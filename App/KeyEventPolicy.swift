import AppKit
import KeyKeyEngine

// Pure decisions for InputController — key-event routing, input-session lifecycle, and whether
// user learning shapes the candidate order — kept free of IMK/engine state so they can be
// unit-tested. All three policies live in this one file because tools/build-app.sh compiles an
// explicit list of App/ sources; a separate file would need to be added there too.
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

    /// U+3000 IDEOGRAPHIC SPACE — the full-width space (全形空白), one Chinese character wide.
    static let fullWidthSpace = "\u{3000}"

    /// Whether this key press types a full-width space (issue #135): Shift + Space, with no
    /// ⌃⌥⌘, while the option is on. Matched by key code like every other Space check, so it holds
    /// on any keyboard layout. Caps Lock does not matter.
    ///
    /// Off (the default), Shift + Space keeps behaving exactly like Space.
    static func typesFullWidthSpace(enabled: Bool, keyCode: UInt16,
                                    modifierFlags: NSEvent.ModifierFlags) -> Bool {
        enabled && keyCode == 49 && modifierFlags.contains(.shift)
            && modifierFlags.intersection([.control, .option, .command]).isEmpty
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

// Whether user learning shapes the candidate order, and what gets counted (issues #85, #130).
//
// For 倉頡, 速成 and 聯想字詞, adaptive ordering counts how often each candidate is committed IN
// ITS OWN candidate list and orders that list by the count — most-committed first, with the
// built-in order deciding whenever counts are equal. See CandidateOrdering and
// CandidateUsageStore for the rule itself.
//
// 拼音 is deliberately NOT part of that: its ranking is out of scope for this change and keeps
// using the per-character bonus it always used (`bonus`/`characterToLearn` below, over
// UserFrequency). Both mechanisms answer to the SAME setting, so the toggle still means one thing
// to the user, and both are paused and ignored together when it is off.
//
// Adaptive ordering is ON by default. Turned off, candidates keep the static order the selected
// table and ranking give them (五代 its built-in corpus ranking, 三代 the original Yahoo! KeyKey
// line order, 拼音 and 聯想 the language model's own), so a typist who has memorised positions can
// rely on them. Counting is PAUSED, not erased: nothing new is counted, stored counts are ignored
// rather than deleted, and turning it back on resumes where it left off.
//
// InputController itself needs a live IMKServer and cannot be unit-tested, which is why the two
// decisions live here rather than inline at the call sites.
enum AdaptiveCandidateOrder {
    /// The count to sort `candidate` by within `list` — the stored count while adaptive ordering
    /// is on, zero when off.
    ///
    /// Zero is what makes the fallback work rather than a special case: every consumer sorts on
    /// this count first and falls back to the built-in order, so an all-zero answer leaves the
    /// 倉頡/速成 lists, the 拼音 walker's node candidates and the 聯想 list each with exactly the
    /// order they had before any learning. The engine tests pin that ("a fresh store preserves
    /// every untrained list exactly").
    static func count(of candidate: String, in list: CandidateListKey, enabled: Bool,
                      stored: (String, CandidateListKey) -> Int) -> Int {
        enabled ? stored(candidate, list) : 0
    }

    /// The usage a commit should credit: what the engine reported it is about to commit while
    /// adaptive ordering is on, nothing when off — the setting pauses counting as well as
    /// ignoring counts, so a user who turned it off is not still being counted.
    static func usageToRecord(_ pending: [CandidateUsage], enabled: Bool) -> [CandidateUsage] {
        enabled ? pending : []
    }

    // MARK: 拼音 — the per-character mechanism, unchanged from before this release

    /// The ranking bonus to apply for `char` — the learned bonus while adaptive ordering is on,
    /// zero when off. Consumed only by the 拼音 walker now that 倉頡/速成/聯想 count per list.
    static func bonus(for char: Character, enabled: Bool,
                      learned: (Character) -> Double) -> Double {
        enabled ? learned(char) : 0
    }

    /// The character to learn from a committed composition, or nil when there is nothing to learn.
    ///
    /// Only a commit whose WHOLE text is one character, because UserFrequency counts characters —
    /// a multi-character 拼音 commit has no single character to attribute. Still fed by EVERY
    /// mode's single-character commits, as before, because that is what 拼音 ranks by; dropping
    /// the 倉頡/速成 commits here would change 拼音's behaviour, which this release does not.
    static func characterToLearn(fromCommitted text: String, enabled: Bool) -> Character? {
        guard enabled, text.count == 1 else { return nil }
        return text.first
    }

    /// The character to learn from a picked 聯想 phrase, given the suffix that pick inserts
    /// (`KeyEventPolicy.associationSuffix`), or nil when there is nothing to learn.
    ///
    /// The FIRST character of the suffix — 係 for 關係 — whatever the phrase's length. This no
    /// longer orders the 聯想 list itself (`usageToRecord(forAssociationPhrase:)` does), but it
    /// still feeds 拼音, so it is kept for that.
    static func characterToLearn(fromAssociationSuffix suffix: String, enabled: Bool) -> Character? {
        guard enabled else { return nil }
        return suffix.first
    }

    /// The usage a picked 聯想 phrase should credit: the WHOLE phrase — 關係, not the continuation
    /// 係 the 聯想只顯示接續字 option may be displaying — in the list its trigger character opens.
    ///
    /// The trigger is the phrase's own first character, which is exactly how `AssociatedPhrases`
    /// buckets its lists, so the two cannot drift apart. The key carries no input mode and no
    /// input code on purpose: 倉頡 and 速成 show the same list after the same character and must
    /// share one set of counts.
    static func usageToRecord(forAssociationPhrase phrase: String, enabled: Bool) -> [CandidateUsage] {
        guard enabled, phrase.count >= 2, let trigger = phrase.first else { return [] }
        return [CandidateUsage(list: .association(trigger: trigger), candidate: phrase)]
    }
}
