import AppKit
import SwiftUI
import DragonKit
import DragonKitUpdates

// Host-owned owner of the shared DragonKit settings window for the IME. The IMK input menu
// (InputController.menu) routes 關於 / 檢查更新… / 設定… here; each sets the target pane before
// showing the window, so About opens About, Updates opens Updates, etc. Uninstall has no menu
// entry point by design (see DragonAppMenu) — its pane is reached from the sidebar.
//
// Sidebar order (host-owned): General → Sync & Backup → What's New → Updates → About →
// Uninstall. No Permissions pane (KeyKey uses no Accessibility/Input-Monitoring). No Quit /
// launch-at-login (an IME is system-managed).
@MainActor
final class AppMenuController {
    static let shared = AppMenuController()

    private let model = SettingsModel()
    private let updater = DragonUpdater()
    private let selection = SettingsSelection()

    private init() {}

    private lazy var settingsController: DragonSettingsWindowController = {
        if selection.paneID == nil { selection.paneID = "general" }
        return DragonSettingsWindowController(
            title: AboutConfig.appName,
            // Same reason, and the same spelling, as the includeQuit: false the IMK dropdown
            // passes to DragonAppMenu (InputController): a system-managed IME is quit by the
            // system, not by the user. The kit installs a menu bar while Settings is open, so
            // without this the settings menu bar would reintroduce the Quit ⌘Q the dropdown
            // deliberately omits. Not installsMainMenu: false — that would also drop ⌘W and
            // Cut/Copy/Paste, which settings text fields get only from these menu items.
            includeQuit: false,
            rootView: SettingsRoot(
                appName: AboutConfig.appName,
                panesBuilder: { [weak self] in self?.settingsPanes ?? [] },
                selection: selection
            )
        )
    }()

    private var settingsPanes: [AnySettingsPane] {
        [
            AnySettingsPane(GeneralPane(model: model)),
            AnySettingsPane(BackupSettingsPane(config: backupConfig)),
            AnySettingsPane(WhatsNewSettingsPane(content: WhatsNewConfig.content)),
            AnySettingsPane(UpdatesSettingsPane(updater: updater)),
            AnySettingsPane(AboutSettingsPane(content: AboutConfig.content)),
            AnySettingsPane(UninstallSettingsPane(config: uninstallConfig, onCancel: { [selection] in
                selection.paneID = "general"
            })),
        ]
    }

    // Backup snapshots KeyKey's whole settings domain (its bundle-id standard defaults) — the
    // same domain Preferences and Sparkle persist into.
    private var backupConfig: BackupConfig {
        BackupConfig(
            appName: AboutConfig.appName,
            suiteName: SettingsModel.suiteName,
            appVersion: AboutConfig.versionString,
            relaunch: { [weak self] in self?.relaunch() }
        )
    }

    // Uninstall config ported from the old Uninstaller.swift: wipe the bundle-id defaults
    // domain, the Application Support/YahooKeyKey2 dir (user-frequency.json), and caches; then
    // DragonUninstaller moves the bundle to the Trash. The bundle here is the IME under
    // ~/Library/Input Methods.
    private var uninstallConfig: UninstallConfig {
        let library = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library")
        let bundleID = Bundle.main.bundleIdentifier ?? "com.dragonapp.inputmethod.yahoo-keykey"
        return UninstallConfig(
            appName: AboutConfig.appName,
            bundleID: bundleID,
            suiteNames: [],
            checklistItems: [
                L("keykey.uninstall.item.inputSources"),
                L("keykey.uninstall.item.learningAndSettings"),
                L("keykey.uninstall.item.trash"),
            ],
            extraCleanupPaths: [
                library.appending(path: "Application Support/YahooKeyKey2"),
                library.appending(path: "Caches/\(bundleID)"),
            ]
        )
    }

    // MARK: - IMK menu entry points

    func openSettings() {
        selection.paneID = "general"
        model.syncFromPreferences()
        settingsController.show()
    }

    func openAbout() {
        selection.paneID = "about"
        model.syncFromPreferences()
        settingsController.show()
    }

    func checkForUpdates() {
        selection.paneID = "updates"
        model.syncFromPreferences()
        settingsController.show()
        updater.checkForUpdates()
    }

    private func relaunch() {
        // Deselect our input sources and quit; macOS relaunches the IME on next keystroke,
        // picking up the restored settings. (An IME can't cleanly re-open itself as an app.)
        NSApp.terminate(nil)
    }
}

// Host-owned settings selection: set paneID before showing so the menu opens directly to a
// specific pane (even on the first lazy window open).
@MainActor
@Observable
final class SettingsSelection {
    var paneID: String?
}

// Settings root: observes LocalizationManager and rebuilds host-supplied panes (About /
// What's New re-localize) on language change, then applies .dragonLocalized() so the whole
// window switches language live.
private struct SettingsRoot: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let appName: String
    let panesBuilder: () -> [AnySettingsPane]
    let selection: SettingsSelection

    var body: some View {
        SettingsPaneList(appName: appName, panes: panesBuilder(), selection: selection)
            .dragonLocalized()
    }
}

private struct SettingsPaneList: View {
    let appName: String
    let panes: [AnySettingsPane]
    @Bindable var selection: SettingsSelection

    var body: some View {
        SettingsShell(appName: appName, panes: panes, selection: $selection.paneID)
    }
}
