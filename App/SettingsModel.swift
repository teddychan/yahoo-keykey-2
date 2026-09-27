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

    // Shift + 空白鍵輸入全形空白 (issue #135). A plain toggle, so a computed forwarder is fine;
    // InputController reads Preferences live on every key press.
    var shiftSpaceFullWidthSpace: Bool {
        get { Preferences.shiftSpaceFullWidthSpaceEnabled }
        set { Preferences.shiftSpaceFullWidthSpaceEnabled = newValue }
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

    // 以空白鍵確認字根 (issue #61): in 速成 / 倉頡-with-`*`, require one Space press to confirm the
    // typed strokes before Space resumes paging or committing. A plain toggle, so a computed
    // forwarder is fine here — only Picker/Slider need the stored-property treatment below.
    var strokeConfirmation: Bool {
        get { Preferences.strokeConfirmationEnabled }
        set { Preferences.strokeConfirmationEnabled = newValue }
    }

    // 依選字習慣調整候選字順序 (issue #85): whether user learning ranks candidates and 聯想, or the
    // built-in order stands. Another plain toggle, so a computed forwarder is right — InputController
    // reads Preferences live on every sort and every commit, so nothing needs rebuilding here.
    var adaptiveCandidateOrder: Bool {
        get { Preferences.adaptiveCandidateOrderEnabled }
        set { Preferences.adaptiveCandidateOrderEnabled = newValue }
    }

    // Candidate text size. Like `cangjieVersion` below, this is a STORED, observation-tracked
    // property (seeded from Preferences at init) — NOT a computed forwarder. An @Observable
    // *computed* property bound to a Slider never registers an observation dependency in its
    // getter, so SwiftUI drops the change: the slider (and its "N pt" label) appear frozen while
    // dragging. A stored property is tracked, so the value updates live. `didSet` writes through
    // to Preferences, which the candidate window reads directly on the next composition.
    var candidateFontSize: Double = Double(Preferences.candidateFontSize) {
        didSet {
            guard candidateFontSize != oldValue else { return }
            Preferences.candidateFontSize = CGFloat(candidateFontSize)
        }
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

    // 注音鍵盤. Stored + observation-tracked like `cangjieVersion` above (a computed forwarder
    // would make the menu-style Picker's selection silently revert). `didSet` writes through to
    // Preferences and posts the notification every live engine rebuilds on — the same one the
    // input menu's 注音鍵盤 items post, so both routes to this setting behave identically.
    // Nothing in SharedResources is reloaded: the ㄅ半 table is the same table whichever keyboard
    // types it.
    //
    // Unlike cangjieVersion, this setting has a SECOND writer — the input menu writes Preferences
    // directly — so this mirror can fall behind it. Two things keep that harmless. The guard
    // compares against Preferences, not oldValue, so picking the value a stale Picker already
    // shows is still written; comparing against oldValue made that pick a no-op, and the user could
    // not switch back from Settings at all. And init follows .zhuyinLayoutChanged, so the Picker
    // tracks an input-menu change even while the window is open; a value re-seeded from there
    // already matches Preferences, so the guard stops it re-posting.
    var zhuyinLayout: ZhuyinLayout = Preferences.zhuyinLayout {
        didSet {
            guard zhuyinLayout != Preferences.zhuyinLayout else { return }
            Preferences.zhuyinLayout = zhuyinLayout
            NotificationCenter.default.post(name: .zhuyinLayoutChanged, object: nil)
        }
    }

    // Never removed: the one SettingsModel lives as long as the process (AppMenuController.shared),
    // and the block holds it weakly.
    @ObservationIgnored private var zhuyinLayoutObserver: NSObjectProtocol?

    init() {
        zhuyinLayoutObserver = NotificationCenter.default.addObserver(
            forName: .zhuyinLayoutChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Only when behind: a change made in this window already matches Preferences, and
            // skipping it avoids re-entering didSet from inside its own post.
            MainActor.assumeIsolated {
                let current = Preferences.zhuyinLayout
                if self.zhuyinLayout != current { self.zhuyinLayout = current }
            }
        }
    }

    // 聯想選字鍵 (issue #52). Stored + observation-tracked like `cangjieVersion` above so the
    // menu-style Picker selection sticks (a computed forwarder would silently revert). `didSet`
    // writes through to Preferences, which InputController reads live on the next composition.
    var associationTrigger: AssociationTrigger = Preferences.associationSelectionTrigger {
        didSet {
            guard associationTrigger != oldValue else { return }
            Preferences.associationSelectionTrigger = associationTrigger
        }
    }

    var minFontSize: Double { Double(Preferences.minFontSize) }
    var maxFontSize: Double { Double(Preferences.maxFontSize) }

    // Re-seed the observation-tracked mirror properties (candidateFontSize, zhuyinLayout) from
    // the live Preferences. The computed forwarders above re-read Preferences on every access, so
    // they always reflect changes made elsewhere; a stored property does not. Call this before
    // showing the window so the slider matches whatever value Preferences currently holds (e.g. a
    // value migrated from an older build). No-op when already in sync (the didSet guard skips the write).
    func syncFromPreferences() {
        candidateFontSize = Double(Preferences.candidateFontSize)
        zhuyinLayout = Preferences.zhuyinLayout
    }
}
