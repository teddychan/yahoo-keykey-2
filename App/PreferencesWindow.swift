import Cocoa

// A small, native AppKit Preferences window for the three v1.0.0 settings. A single shared
// instance; `show()` brings it to front and activates the LSUIElement background app so the
// window is actually visible. Controls write straight to `Preferences` (UserDefaults).
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private let fontSizeStepper = NSStepper()
    private let fontSizeLabel = NSTextField(labelWithString: "")
    private let associatedPhrasesCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fullWidthPunctuationCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 170),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "偏好設定"
        super.init(window: window)
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let fontTitle = NSTextField(labelWithString: "候選字大小")
        fontSizeStepper.minValue = Double(Preferences.minFontSize)
        fontSizeStepper.maxValue = Double(Preferences.maxFontSize)
        fontSizeStepper.increment = 1
        fontSizeStepper.target = self
        fontSizeStepper.action = #selector(fontSizeChanged)

        associatedPhrasesCheckbox.title = "聯想字詞"
        associatedPhrasesCheckbox.target = self
        associatedPhrasesCheckbox.action = #selector(associatedPhrasesChanged)

        fullWidthPunctuationCheckbox.title = "全形標點"
        fullWidthPunctuationCheckbox.target = self
        fullWidthPunctuationCheckbox.action = #selector(fullWidthPunctuationChanged)

        let fontRow = NSStackView(views: [fontTitle, fontSizeStepper, fontSizeLabel])
        fontRow.spacing = 8
        fontRow.alignment = .centerY

        let stack = NSStackView(views: [fontRow, associatedPhrasesCheckbox, fullWidthPunctuationCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
        ])
    }

    // Reflect current persisted values into the controls each time the window opens.
    private func syncControls() {
        fontSizeStepper.integerValue = Int(Preferences.candidateFontSize)
        fontSizeLabel.stringValue = "\(Int(Preferences.candidateFontSize)) pt"
        associatedPhrasesCheckbox.state = Preferences.associatedPhrasesEnabled ? .on : .off
        fullWidthPunctuationCheckbox.state = Preferences.fullWidthPunctuationEnabled ? .on : .off
    }

    func show() {
        syncControls()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func fontSizeChanged() {
        Preferences.candidateFontSize = CGFloat(fontSizeStepper.integerValue)
        fontSizeLabel.stringValue = "\(Int(Preferences.candidateFontSize)) pt"
    }

    @objc private func associatedPhrasesChanged() {
        Preferences.associatedPhrasesEnabled = (associatedPhrasesCheckbox.state == .on)
    }

    @objc private func fullWidthPunctuationChanged() {
        Preferences.fullWidthPunctuationEnabled = (fullWidthPunctuationCheckbox.state == .on)
    }
}
