import Cocoa

// Minimal borderless candidate list. Numbered 1..9; display only (selection is by number key).
final class CandidateWindow {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        label.font = .systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
        ])
        panel.contentView = content
    }

    // `pageCandidates` is the already-sliced set for the current page (≤9). When `pageCount`
    // exceeds 1, a " (page/total)" indicator is appended. `fontSize` is read live from
    // Preferences by the caller so size changes apply without restarting the IME.
    func show(_ pageCandidates: [String], page: Int, pageCount: Int, fontSize: CGFloat, near point: NSPoint) {
        label.font = .systemFont(ofSize: fontSize)
        var shown = pageCandidates.prefix(9).enumerated()
            .map { "\($0.offset + 1).\($0.element)" }
            .joined(separator: "  ")
        if pageCount > 1 { shown += "  (\(page + 1)/\(pageCount))" }
        label.stringValue = shown
        panel.setContentSize(label.intrinsicContentSize)
        panel.setFrameTopLeftPoint(NSPoint(x: point.x, y: point.y - 4))
        panel.orderFront(nil)
    }

    func hide() { panel.orderOut(nil) }
}
