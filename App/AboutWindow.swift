import Cocoa

// A small, native AppKit About window. A single shared instance; `show()` brings it to front
// and activates the LSUIElement background app so the window is actually visible. Mirrors the
// PreferencesWindowController pattern. Content is static: name, version, one-line description,
// a credit to the original Yahoo! KeyKey projects, and the attributions for the bundled data.
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "關於 Yahoo KeyKey 2"
        super.init(window: window)
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

        let nameLabel = NSTextField(labelWithString: "Yahoo KeyKey 2")
        nameLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)

        let versionLabel = NSTextField(labelWithString: "版本 \(version)")
        versionLabel.textColor = .secondaryLabelColor

        let descriptionLabel = NSTextField(labelWithString: "倉頡／簡易 輸入法")

        let originHeading = NSTextField(labelWithString: "向原版 Yahoo! KeyKey 致敬")
        originHeading.font = NSFont.systemFont(ofSize: 12, weight: .semibold)

        let originAttribution = NSTextField(wrappingLabelWithString:
            "本軟體是獨立重製版，並非 Yahoo 官方產品，謹向已停止維護的原版 Yahoo! KeyKey 致敬。\n" +
            "原版專案：ninjapanda/YahooKeyKey\n" +
            "    https://github.com/ninjapanda/YahooKeyKey\n" +
            "原版安裝程式：zonble/ykk_installer\n" +
            "    https://github.com/zonble/ykk_installer")
        originAttribution.font = NSFont.systemFont(ofSize: 11)
        originAttribution.textColor = .secondaryLabelColor

        let dataHeading = NSTextField(labelWithString: "資料與引擎來源")
        dataHeading.font = NSFont.systemFont(ofSize: 12, weight: .semibold)

        let attribution = NSTextField(wrappingLabelWithString:
            "語言模型來自 openvanilla/McBopomofo。\n" +
            "倉頡碼表來自 ibus-table-chinese（可自由轉散布）。\n" +
            "漢字轉換資料來自 OpenCC（Apache-2.0）。")
        attribution.font = NSFont.systemFont(ofSize: 11)
        attribution.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [nameLabel, versionLabel, descriptionLabel,
                                        originHeading, originAttribution,
                                        dataHeading, attribution])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(4, after: originHeading)
        stack.setCustomSpacing(4, after: dataHeading)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
        ])
    }

    func show() {
        // LSUIElement background app: must activate (ignoringOtherApps: true) for the window
        // to actually come forward when the user picks 關於 from the input menu.
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.level = .floating
        window?.makeKeyAndOrderFront(nil)
    }
}
