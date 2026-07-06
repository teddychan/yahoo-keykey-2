import Foundation
import DragonKit

// Observable bridge between the DragonKit settings UI (SwiftUI) and KeyKey's persisted
// preferences. Every property forwards to the existing `Preferences` accessors, which the
// input engine, candidate window, and SharedResources read LIVE — so a change in the
// General pane applies on the next composition without restarting the IME, exactly as the
// input-menu toggles do.
//
// Settings preservation: this deliberately does NOT introduce a new UserDefaults suite or a
// single JSON blob. It reads and writes the SAME individual keys in the SAME domain
// (UserDefaults.standard, i.e. the IME's bundle-id domain) that `Preferences` has always
// used, so an existing install's settings are read unchanged and never reset. `DragonBackup`
// still snapshots the whole domain by name (see AppMenuController.backupConfig).
@MainActor
@Observable
final class SettingsModel {
    // The domain KeyKey has always persisted into: the IME process's standard defaults, whose
    // name is the app's bundle id. Backup snapshots this whole domain.
    static var suiteName: String { Bundle.main.bundleIdentifier ?? "com.dragonapp.inputmethod.yahoo-keykey" }

    var outputSimplified: Bool {
        get { Preferences.outputSimplifiedEnabled }
        set { Preferences.outputSimplifiedEnabled = newValue }
    }

    var fullWidthPunctuation: Bool {
        get { Preferences.fullWidthPunctuationEnabled }
        set { Preferences.fullWidthPunctuationEnabled = newValue }
    }

    var associatedPhrases: Bool {
        get { Preferences.associatedPhrasesEnabled }
        set { Preferences.associatedPhrasesEnabled = newValue }
    }

    // 聯想只顯示接續字 (v2.2.0 feature): show only the continuation after the committed character
    // in the 聯想 window. Forwards to the pre-existing Preferences key (not redefined here).
    var associationContinuationOnly: Bool {
        get { Preferences.associationContinuationOnly }
        set { Preferences.associationContinuationOnly = newValue }
    }

    // 反查/拆碼提示: show each single character's 倉頡 code in the candidate window.
    var codeHint: Bool {
        get { Preferences.codeHintEnabled }
        set { Preferences.codeHintEnabled = newValue }
    }

    var candidateFontSize: Double {
        get { Double(Preferences.candidateFontSize) }
        set { Preferences.candidateFontSize = CGFloat(newValue) }
    }

    // 倉頡版本 (Cangjie table). This is a STORED, observation-tracked property (seeded from
    // Preferences at init) — NOT a computed forwarder like the toggles above. A menu-style
    // Picker bound to an @Observable *computed* property silently reverts its selection (the
    // getter never registers an observation dependency, so SwiftUI drops the change); a stored
    // property is tracked, so the Picker sticks. `didSet` writes through to Preferences (the
    // engine reads that directly) and reloads the shared tables + live engines.
    var cangjieVersion: CangjieVersion = Preferences.cangjieVersion {
        didSet {
            guard cangjieVersion != oldValue else { return }
            Preferences.cangjieVersion = cangjieVersion
            SharedResources.shared.reloadCangjieTables()
        }
    }

    var minFontSize: Double { Double(Preferences.minFontSize) }
    var maxFontSize: Double { Double(Preferences.maxFontSize) }
}
