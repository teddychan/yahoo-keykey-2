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
    func show(_ pageCandidates: [String], page: Int, pageCount: Int, fontSize: CGFloat, near caret: NSRect) {
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
        positionPanel(near: caret)
        panel.orderFront(nil)
    }

    // Place the window just below the caret; flip above if it would run off the bottom; clamp
    // horizontally so the whole window stays on the caret's screen. The caret rect is in screen
    // coordinates (Cocoa, y-up): minY = caret bottom, maxY = caret top.
    private func positionPanel(near caret: NSRect) {
        let size = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.intersects(caret) }
            ?? NSScreen.main ?? NSScreen.screens.first
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        // Some clients report an empty (0,0) caret rect: fall back to screen centre.
        let anchor = (caret.width == 0 && caret.height == 0)
            ? NSRect(x: vf.midX, y: vf.midY, width: 1, height: 16) : caret
        let gap: CGFloat = 4
        var x = anchor.minX
        var top = anchor.minY - gap                      // window top just below the caret
        if top - size.height < vf.minY {                 // would run off the bottom -> flip above
            top = anchor.maxY + gap + size.height
        }
        if x + size.width > vf.maxX { x = vf.maxX - size.width }       // clamp right
        if x < vf.minX { x = vf.minX }                                // clamp left
        if top > vf.maxY { top = vf.maxY }                            // clamp top
        if top - size.height < vf.minY { top = vf.minY + size.height } // final bottom clamp
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: top))
    }

    func hide() { panel.orderOut(nil) }
}
