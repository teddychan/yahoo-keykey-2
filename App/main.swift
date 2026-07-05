import Cocoa
import InputMethodKit
import DragonKit

// Retain the server for process lifetime.
var server: IMKServer?

guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      let bundleID = Bundle.main.bundleIdentifier else {
    NSLog("YahooKeyKey: missing Info.plist keys"); exit(EXIT_FAILURE)
}
Preferences.registerDefaults()
// KeyKey ships loose .lproj in the .app, so its own app-specific strings (pane titles, About
// text, etc.) resolve from .main. DragonKit's own UI strings come from its bundle. Top-level
// main.swift runs on the main thread, so it's safe to enter the main actor here.
MainActor.assumeIsolated {
    LocalizationManager.shared.appStringsBundle = .main
}
server = IMKServer(name: connectionName, bundleIdentifier: bundleID)
if server == nil { NSLog("YahooKeyKey: failed to create IMKServer"); exit(EXIT_FAILURE) }
// Prewarm the shared resources off the main thread during IMK startup so the one-time
// data.txt parse happens before the first controller is created (later inits are instant).
DispatchQueue.global(qos: .userInitiated).async { _ = SharedResources.shared }

// Flush pending user-learning counts on a clean quit. Best-effort: IMK agents can also be
// killed without terminating, but this closes the common-quit gap within the save debounce.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        SharedResources.shared.userFreq.flush()
    }
}
let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate

NSApplication.shared.run()
