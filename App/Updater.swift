import AppKit
import Sparkle

/// Owns the Sparkle updater for the lifetime of the input-method process.
/// Sparkle reads SUFeedURL / SUPublicEDKey / SUEnableAutomaticChecks from
/// Info.plist, so this wrapper only starts the controller and exposes a
/// manual check for the input menu.
///
/// Guarded: if SUPublicEDKey is absent (e.g. an ad-hoc dev build that skipped
/// the key), the updater is not started — Sparkle requires the key and would
/// otherwise log errors on every launch.
///
/// LSUIElement gotcha: the IME is a background agent, so Sparkle's check /
/// result / update windows do not come to the front on their own — they open
/// behind whatever app the user is typing into and look like nothing happened.
/// We activate the app (ignoringOtherApps) when a manual check starts and again,
/// via SPUStandardUserDriverDelegate, right before Sparkle shows each window or
/// alert. Mirrors AboutWindowController.show(), which needs the same treatment.
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    static let shared = Updater()

    private var controller: SPUStandardUpdaterController?

    private override init() {
        super.init()
        let hasKey = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?.isEmpty == false
        guard hasKey else {
            NSLog("YahooKeyKey: SUPublicEDKey missing; auto-update disabled")
            return
        }
        // startingUpdater: true begins scheduled checks using the Info.plist config.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }

    /// Auto-check preference, surfaced in the Settings 更新 pane. Backed by Sparkle (persisted
    /// in the same UserDefaults domain). No-op when the updater is disabled (missing SUPublicEDKey).
    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Manual check, wired to the "檢查更新…" input-menu item.
    func checkForUpdates() {
        // Background agent: bring the app forward so the check/result window is visible.
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    // MARK: - SPUStandardUserDriverDelegate

    // Sparkle presents its UI asynchronously; re-activate right before each window or
    // alert so it lands in front of the app the user is typing into, not buried behind it.

    func standardUserDriverWillShowModalAlert() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
