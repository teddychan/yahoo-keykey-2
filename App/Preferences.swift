import Cocoa

// Which Cangjie decomposition table (and, for the Yahoo table, candidate order) the
// 倉頡/速成 engines use. 五代 keeps the standard McBopomofo LM ranking; 三代 uses the
// original Yahoo! KeyKey table (cj-ext.cin) and its native candidate order.
enum CangjieVersion: String {
    case v5 = "5"          // 五代倉頡 (default) — bundled ibus cangjie5 table + LM ranking
    case v3 = "3"          // 三代倉頡 — Yahoo! KeyKey cj-ext table + native order
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
        static let englishToggleShortcut = "englishToggleShortcut"
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

    // The user-chosen shortcut that toggles 中/英 (quick-English) mode. Falls back to the
    // classic KeyKey default (right-Shift tap) when unset or unparseable.
    static var englishToggleShortcut: ShortcutSpec {
        get {
            UserDefaults.standard.string(forKey: Key.englishToggleShortcut)
                .flatMap(ShortcutSpec.init(serialized:)) ?? .default
        }
        set { UserDefaults.standard.set(newValue.serialized, forKey: Key.englishToggleShortcut) }
    }
}
