import Cocoa

// Which Cangjie decomposition table (and, for the Yahoo table, candidate order) the
// 倉頡/速成 engines use. 五代 keeps the standard McBopomofo LM ranking; 三代 uses the
// original Yahoo! KeyKey table (cj-ext.cin) and its native candidate order.
enum CangjieVersion: String {
    case v5 = "5"          // 五代倉頡 (default) — bundled ibus cangjie5 table + LM ranking
    case v3 = "3"          // 三代倉頡 — Yahoo! KeyKey cj-ext table + native order
}

// Which key selects an associated phrase (聯想) in the numbered candidate window.
// `.number` keeps the classic direct 1–9 pick; `.shift` requires Shift+1–9 so a bare
// 1–9 types the digit instead — smoother when mixing numbers with Chinese (issue #52).
enum AssociationTrigger: String {
    case number = "number"   // default — plain 1–9 picks
    case shift  = "shift"    // Shift+1–9 picks; plain 1–9 types the digit
}

// Typed accessors for the user-facing settings, persisted in the IME process's
// standard UserDefaults. Read live (no caching) so changes apply without restarting.
enum Preferences {
    private enum Key {
        static let candidateFontSize = "candidateFontSize"
        static let associatedPhrasesEnabled = "associatedPhrasesEnabled"
        static let fullWidthPunctuationEnabled = "fullWidthPunctuationEnabled"
        static let outputSimplifiedEnabled = "outputSimplifiedEnabled"
        static let cangjieVersion = "cangjieVersion"
        static let associationContinuationOnly = "associationContinuationOnly"
        static let codeHintEnabled = "codeHintEnabled"
        static let associationSelectionTrigger = "associationSelectionTrigger"
        static let strokeConfirmationEnabled = "strokeConfirmationEnabled"
        static let adaptiveCandidateOrderEnabled = "adaptiveCandidateOrderEnabled"
    }

    static let minFontSize: CGFloat = 14
    static let maxFontSize: CGFloat = 28
    static let defaultFontSize: CGFloat = 18

    // Register defaults once at process start so first launch reads sensible values.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.candidateFontSize: Double(defaultFontSize),
            Key.associatedPhrasesEnabled: true,
            Key.fullWidthPunctuationEnabled: true,
            Key.outputSimplifiedEnabled: false,
            Key.cangjieVersion: CangjieVersion.v5.rawValue,
            Key.associationContinuationOnly: false,
            Key.codeHintEnabled: false,
            Key.associationSelectionTrigger: AssociationTrigger.number.rawValue,
            Key.strokeConfirmationEnabled: false,
            Key.adaptiveCandidateOrderEnabled: true,
        ])
    }

    static var candidateFontSize: CGFloat {
        get {
            let raw = CGFloat(UserDefaults.standard.double(forKey: Key.candidateFontSize))
            return min(max(raw, minFontSize), maxFontSize)
        }
        set {
            UserDefaults.standard.set(Double(min(max(newValue, minFontSize), maxFontSize)),
                                      forKey: Key.candidateFontSize)
        }
    }

    static var associatedPhrasesEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.associatedPhrasesEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.associatedPhrasesEnabled) }
    }

    static var fullWidthPunctuationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.fullWidthPunctuationEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.fullWidthPunctuationEnabled) }
    }

    static var outputSimplifiedEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.outputSimplifiedEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.outputSimplifiedEnabled) }
    }

    // Selected Cangjie table; unknown/absent falls back to 五代 (the registered default).
    static var cangjieVersion: CangjieVersion {
        get { CangjieVersion(rawValue: UserDefaults.standard.string(forKey: Key.cangjieVersion) ?? "") ?? .v5 }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.cangjieVersion) }
    }

    // When true, the 聯想 (associated-phrase) candidate window shows only the continuation
    // after the just-committed character (係／心／於) instead of the whole word (關係／關心／
    // 關於) — the classic Yahoo! KeyKey display. Off by default (shows the whole word).
    static var associationContinuationOnly: Bool {
        get { UserDefaults.standard.bool(forKey: Key.associationContinuationOnly) }
        set { UserDefaults.standard.set(newValue, forKey: Key.associationContinuationOnly) }
    }

    // When true, the candidate window shows each single character's 倉頡 code as radical glyphs
    // (反查/拆碼提示). Off by default; read live so the menu/Settings toggle applies immediately.
    static var codeHintEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.codeHintEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.codeHintEnabled) }
    }

    // Which key selects an associated phrase; unknown/absent falls back to plain number keys.
    static var associationSelectionTrigger: AssociationTrigger {
        get { AssociationTrigger(rawValue: UserDefaults.standard.string(forKey: Key.associationSelectionTrigger) ?? "") ?? .number }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.associationSelectionTrigger) }
    }

    // When true, an auto-completed composition — 速成, or 倉頡 with a `*` wildcard — needs one
    // Space press to CONFIRM the typed strokes before Space resumes its usual paging/commit
    // role (issue #61). Off by default, so existing users see no change.
    static var strokeConfirmationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.strokeConfirmationEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.strokeConfirmationEnabled) }
    }

    // When true (the default), the characters the user commits are counted and that count ranks
    // the candidates — in 倉頡, 速成, 拼音 and 聯想 alike. Off, the built-in order stands and
    // nothing is counted; see AdaptiveCandidateOrder, which holds the decision this drives, and
    // issue #85 for why a typist who has memorised the order wants that.
    static var adaptiveCandidateOrderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.adaptiveCandidateOrderEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.adaptiveCandidateOrderEnabled) }
    }
}
