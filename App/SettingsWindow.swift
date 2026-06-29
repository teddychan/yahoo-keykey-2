import Cocoa

// The net-new Settings window, opened from the input menu's 設定… item. A small, native
// AppKit NSWindowController mirroring AboutWindowController: a single shared instance whose
// show() activates the LSUIElement agent so the window actually comes forward.
//
// IA follows the shared per-app spec: 一般 (the three real input toggles) · 外觀 (candidate
// font size with a live preview) · 輸入方式 (read-only mode status + a deep link to System
// Settings) · 更新 (Sparkle auto-check toggle + manual check). Controls bind directly to
// Preferences / the Sparkle updater, which the engine and candidate window read live — so a
// change here applies on the next composition without restarting the IME.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    // Live preview label in the 外觀 tab; re-rendered as the size slider moves.
    private let fontPreview = NSTextField(labelWithString: "")
    private let fontValueLabel = NSTextField(labelWithString: "")

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Yahoo! KeyKey 2 設定"
        super.init(window: window)
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(makeTab("一般", view: generalView()))
        tabView.addTabViewItem(makeTab("外觀", view: appearanceView()))
        tabView.addTabViewItem(makeTab("輸入方式", view: inputMethodsView()))
        tabView.addTabViewItem(makeTab("更新", view: updatesView()))

        content.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            tabView.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            tabView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
    }

    private func makeTab(_ label: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: label)
        item.label = label
        item.view = view
        return item
    }

    // Wrap a tab's controls in a leading-aligned vertical stack pinned to the tab's top.
    private func tabContainer(_ views: [NSView], spacing: CGFloat = 14) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
        ])
        return container
    }

    // MARK: - 一般 (the three real input toggles, same set as the input menu)

    private func generalView() -> NSView {
        let simplified = makeCheckbox("輸出簡體字", state: Preferences.outputSimplifiedEnabled,
                                      action: #selector(toggleSimplified))
        let fullWidth = makeCheckbox("全形標點", state: Preferences.fullWidthPunctuationEnabled,
                                     action: #selector(toggleFullWidth))
        let associated = makeCheckbox("聯想字詞", state: Preferences.associatedPhrasesEnabled,
                                      action: #selector(toggleAssociated))
        return tabContainer([simplified, fullWidth, associated])
    }

    private func makeCheckbox(_ title: String, state: Bool, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.state = state ? .on : .off
        return button
    }

    @objc private func toggleSimplified(_ sender: NSButton) {
        Preferences.outputSimplifiedEnabled = (sender.state == .on)
    }
    @objc private func toggleFullWidth(_ sender: NSButton) {
        Preferences.fullWidthPunctuationEnabled = (sender.state == .on)
    }
    @objc private func toggleAssociated(_ sender: NSButton) {
        Preferences.associatedPhrasesEnabled = (sender.state == .on)
    }

    // MARK: - 外觀 (candidate-window font size, clamped 14–28, with a live preview)

    private func appearanceView() -> NSView {
        let heading = NSTextField(labelWithString: "候選字大小")

        let slider = NSSlider(value: Double(Preferences.candidateFontSize),
                              minValue: Double(Preferences.minFontSize),
                              maxValue: Double(Preferences.maxFontSize),
                              target: self, action: #selector(fontSizeChanged))
        slider.numberOfTickMarks = Int(Preferences.maxFontSize - Preferences.minFontSize) + 1
        slider.allowsTickMarkValuesOnly = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 240).isActive = true

        fontValueLabel.textColor = .secondaryLabelColor
        let sliderRow = NSStackView(views: [slider, fontValueLabel])
        sliderRow.orientation = .horizontal
        sliderRow.spacing = 10

        fontPreview.textColor = .labelColor
        refreshFontPreview()

        return tabContainer([heading, sliderRow, fontPreview])
    }

    @objc private func fontSizeChanged(_ sender: NSSlider) {
        Preferences.candidateFontSize = CGFloat(sender.doubleValue)
        refreshFontPreview()
    }

    private func refreshFontPreview() {
        let size = Preferences.candidateFontSize
        fontValueLabel.stringValue = "\(Int(size)) pt"
        fontPreview.stringValue = "1 字　2 詞　3 例"
        fontPreview.font = NSFont.systemFont(ofSize: size)
    }

    // MARK: - 輸入方式 (read-only status + deep link; modes switch via the system switcher)

    private func inputMethodsView() -> NSView {
        let status = NSTextField(wrappingLabelWithString: "已安裝的輸入模式：倉頡、速成\n切換輸入模式請使用系統的輸入來源切換器。")
        status.textColor = .secondaryLabelColor

        let openButton = NSButton(title: "打開系統設定 ▸ 鍵盤 ▸ 輸入來源",
                                  target: self, action: #selector(openInputSourceSettings))
        return tabContainer([status, openButton])
    }

    @objc private func openInputSourceSettings() {
        // Deep link to the Input Sources pane; opens System Settings if the anchored URL is
        // not honored on this macOS version.
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?InputSources") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 更新 (Sparkle: auto-check toggle + manual check)

    private func updatesView() -> NSView {
        let auto = NSButton(checkboxWithTitle: "自動檢查更新",
                            target: self, action: #selector(toggleAutoUpdate))
        auto.state = Updater.shared.automaticallyChecksForUpdates ? .on : .off

        let checkNow = NSButton(title: "立即檢查更新…", target: self, action: #selector(checkForUpdatesNow))
        return tabContainer([auto, checkNow])
    }

    @objc private func toggleAutoUpdate(_ sender: NSButton) {
        Updater.shared.automaticallyChecksForUpdates = (sender.state == .on)
    }
    @objc private func checkForUpdatesNow() {
        Updater.shared.checkForUpdates()
    }

    // MARK: - Presentation

    func show() {
        // LSUIElement background app: activate (ignoringOtherApps) so the window comes forward
        // when picked from the input menu. Mirrors AboutWindowController.show().
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.level = .floating
        window?.makeKeyAndOrderFront(nil)
    }
}
