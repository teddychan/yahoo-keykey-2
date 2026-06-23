import Cocoa
import InputMethodKit

// Retain the server for process lifetime.
var server: IMKServer?

guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      let bundleID = Bundle.main.bundleIdentifier else {
    NSLog("YahooKeyKey: missing Info.plist keys"); exit(EXIT_FAILURE)
}
Preferences.registerDefaults()
server = IMKServer(name: connectionName, bundleIdentifier: bundleID)
if server == nil { NSLog("YahooKeyKey: failed to create IMKServer"); exit(EXIT_FAILURE) }
// Prewarm the shared resources off the main thread during IMK startup so the one-time
// data.txt parse happens before the first controller is created (later inits are instant).
DispatchQueue.global(qos: .userInitiated).async { _ = SharedResources.shared }
NSApplication.shared.run()
