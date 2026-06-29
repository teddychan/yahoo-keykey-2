import Cocoa
import Carbon

// The net-new uninstall flow, opened from the input menu's 解除安裝… item. An IME is a
// system-managed agent, so ordering matters: we DESELECT/disable the TIS input sources FIRST
// (so macOS stops routing keystrokes to a bundle we're about to delete), then remove our
// on-disk footprint, then move the bundle itself to the Trash and quit.
//
// Honesty (per the shared spec): macOS caches a registered input source until logout, so even
// a clean removal needs a logout/login to fully clear it — the confirmation and the final
// notice say so. We own no helper, XPC service, or login item, so there is nothing else to
// tear down.
enum Uninstaller {

    // Present the destructive confirmation, then perform the uninstall if confirmed.
    // Button layout (spec): Uninstall on the LEFT, Cancel on the RIGHT as the default — so
    // Return/Esc both land on the safe choice. NSAlert lays buttons out right-to-left in the
    // order added, so Cancel is added first (rightmost + default).
    static func run() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "解除安裝 Yahoo! KeyKey 2？"
        alert.informativeText = """
        這將會：
        • 從輸入來源中停用倉頡與速成
        • 刪除使用者學習資料與偏好設定
        • 將 Yahoo! KeyKey 2 移到垃圾桶

        macOS 會將已註冊的輸入法快取到登出為止，完成後可能需要登出再登入才能完全清除。
        """

        let cancel = alert.addButton(withTitle: "取消")       // rightmost + default (Return/Esc)
        let uninstall = alert.addButton(withTitle: "解除安裝") // to the left, destructive
        uninstall.hasDestructiveAction = true
        cancel.keyEquivalent = "\r"

        guard alert.runModal() == .alertSecondButtonReturn else { return }

        perform()
    }

    private static func perform() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.github.teddychan.inputmethod.YahooKeyKey2"

        // 1. Deselect/disable our TIS input sources FIRST.
        disableInputSources(bundleIDPrefix: bundleID)

        // 2. Remove the Application Support directory (user-frequency.json lives here).
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("YahooKeyKey2")
            try? FileManager.default.removeItem(at: dir)
        }

        // 3. Clear preferences: the in-process domain plus the on-disk plist (Sparkle keys
        //    live in this same domain).
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        let prefsPlist = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Preferences/\(bundleID).plist")
        try? FileManager.default.removeItem(at: prefsPlist)

        // 4. Move the (running) bundle to the Trash, then tell the user what remains and quit.
        //    NSWorkspace.recycle works on a running bundle.
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.recycle([bundleURL]) { _, _ in
            DispatchQueue.main.async { finish() }
        }
    }

    // Disable every enabled input source whose id is prefixed by our bundle id (covers the
    // parent source and the Cangjie/Simplex mode ids). Disabling an active source makes macOS
    // fall back to another input source.
    private static func disableInputSources(bundleIDPrefix: String) {
        guard let list = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else { return }
        for source in list {
            guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            let sourceID = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
            if sourceID.hasPrefix(bundleIDPrefix) {
                TISDisableInputSource(source)
            }
        }
    }

    private static func finish() {
        let done = NSAlert()
        done.alertStyle = .informational
        done.messageText = "Yahoo! KeyKey 2 已解除安裝"
        done.informativeText = "已移到垃圾桶。如輸入來源清單仍顯示倉頡／速成，請登出再登入即可完全清除。"
        done.addButton(withTitle: "結束")
        done.runModal()
        NSApp.terminate(nil)
    }
}
