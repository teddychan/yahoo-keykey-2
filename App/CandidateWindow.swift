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

    func show(_ candidates: [String], near point: NSPoint) {
        let shown = candidates.prefix(9).enumerated()
            .map { "\($0.offset + 1).\($0.element)" }
            .joined(separator: "  ")
        label.stringValue = shown
        panel.setContentSize(label.intrinsicContentSize)
        panel.setFrameTopLeftPoint(NSPoint(x: point.x, y: point.y - 4))
        panel.orderFront(nil)
    }

    func hide() { panel.orderOut(nil) }
}
