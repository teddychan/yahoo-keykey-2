import Cocoa

// Typed accessors for the three user-facing settings, persisted in the IME process's
// standard UserDefaults. Read live (no caching) so changes apply without restarting.
enum Preferences {
    private enum Key {
        static let candidateFontSize = "candidateFontSize"
        static let associatedPhrasesEnabled = "associatedPhrasesEnabled"
        static let fullWidthPunctuationEnabled = "fullWidthPunctuationEnabled"
        static let outputSimplifiedEnabled = "outputSimplifiedEnabled"
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
}
