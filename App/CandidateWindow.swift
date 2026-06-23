import Cocoa

// Minimal borderless candidate list. Numbered 1..9 stacked vertically (like the original
// Yahoo! KeyKey picker); display only (selection is by number key).
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
        label.translatesAutoresizingMaskIntoConstraints = false
        label.maximumNumberOfLines = 0
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

    // `pageCandidates` is the already-sliced set for the current page (≤9). Each candidate is
    // rendered on its own row as "N. 字", stacked vertically. When `pageCount` exceeds 1, a
    // bottom row "▲ page/total ▼" indicator is appended. `fontSize` is read live from
    // Preferences by the caller so size changes apply without restarting the IME.
    func show(_ pageCandidates: [String], page: Int, pageCount: Int, fontSize: CGFloat, near point: NSPoint) {
        let glyphFont = NSFont.systemFont(ofSize: fontSize)
        let numFont = NSFont.systemFont(ofSize: max(10, fontSize * 0.7))
        let out = NSMutableAttributedString()
        for (i, cand) in pageCandidates.prefix(9).enumerated() {
            if i > 0 { out.append(NSAttributedString(string: "\n")) }
            out.append(NSAttributedString(
                string: "\(i + 1). ",
                attributes: [.font: numFont, .foregroundColor: NSColor.secondaryLabelColor]))
            out.append(NSAttributedString(
                string: cand,
                attributes: [.font: glyphFont, .foregroundColor: NSColor.labelColor]))
        }
        if pageCount > 1 {
            if out.length > 0 { out.append(NSAttributedString(string: "\n")) }
            out.append(NSAttributedString(
                string: "▲ \(page + 1)/\(pageCount) ▼",
                attributes: [.font: numFont, .foregroundColor: NSColor.secondaryLabelColor]))
        }
        label.attributedStringValue = out
        // Auto-size: width to the widest row, height to the row count.
        panel.setContentSize(label.intrinsicContentSize)
        // Position near the caret (top-left), so a taller window grows downward from the caret.
        panel.setFrameTopLeftPoint(NSPoint(x: point.x, y: point.y - 4))
        panel.orderFront(nil)
    }

    func hide() { panel.orderOut(nil) }
}
