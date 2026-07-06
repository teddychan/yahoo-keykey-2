import Cocoa

// Borderless candidate list styled after the classic Yahoo! KeyKey picker: a rounded, bordered
// box with numbered two-column rows (1..9) and a "▼ page/total" footer. Display only — selection
// is by number key. Colours follow the system appearance (dark box in dark mode, light box in
// light mode); the geometry (border, spacing, font sizes) is mapped from the original app and
// scales with the live candidate font-size preference.
final class CandidateWindow {
    // Geometry mapped from the original app. Sizes that must track the candidate glyph are derived
    // from `fontSize` so the live font-size preference keeps the whole box proportional.
    private enum Style {
        static let cornerRadius: CGFloat = 12
        static let borderWidth: CGFloat = 1.5
        static let insetH: CGFloat = 14          // left/right padding inside the box
        static let insetV: CGFloat = 8           // top/bottom padding inside the box
        static let sectionSpacing: CGFloat = 6   // gaps between header / list / footer
        static func numberSize(_ f: CGFloat) -> CGFloat { max(11, (f * 0.6).rounded()) }
        static func chromeSize(_ f: CGFloat) -> CGFloat { max(11, (f * 0.6).rounded()) }
        static func rowGap(_ f: CGFloat) -> CGFloat { (f * 0.5).rounded() }   // between candidate rows
        static func numberColumn(_ f: CGFloat) -> CGFloat { (f * 1.4).rounded() } // glyph column x
        static let borderAlpha: CGFloat = 0.25
    }

    private let panel: NSPanel
    private let content = NSView()
    private let stack = NSStackView()
    private let candLabel = NSTextField(labelWithString: "")
    private let divider = NSBox()
    private let footerRow = NSView()
    private let footerArrow = NSTextField(labelWithString: "▼")
    private let pageLabel = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // Rounded, bordered, layer-backed container; colours are set per-show so they follow the
        // current appearance. masksToBounds clips the children to the rounded corners.
        content.wantsLayer = true
        content.layer?.cornerRadius = Style.cornerRadius
        content.layer?.borderWidth = Style.borderWidth
        content.layer?.masksToBounds = true

        candLabel.maximumNumberOfLines = 0
        // Let the box widen to whichever row is widest (candidate list vs footer): the candidate
        // label hugs its text only weakly, so the equal-width constraints below resolve both rows
        // to the common maximum.
        candLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        configureChrome(footerArrow)
        configureChrome(pageLabel)
        divider.boxType = .separator

        layoutChromeRow(footerRow, arrow: footerArrow, title: pageLabel)

        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Style.sectionSpacing
        stack.edgeInsets = NSEdgeInsets(top: Style.insetV, left: Style.insetH,
                                        bottom: Style.insetV, right: Style.insetH)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for v in [candLabel, divider, footerRow] { stack.addArrangedSubview(v) }

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            // Full-width rows match the candidate column; equal (not one-directional) so the
            // common width is the max of every row's intrinsic width.
            divider.widthAnchor.constraint(equalTo: candLabel.widthAnchor),
            footerRow.widthAnchor.constraint(equalTo: candLabel.widthAnchor),
        ])
        panel.contentView = content
    }

    private func configureChrome(_ field: NSTextField) {
        field.textColor = .secondaryLabelColor
        field.translatesAutoresizingMaskIntoConstraints = false
    }

    // A header/footer row: arrow pinned to the leading edge, title centred across the full width.
    private func layoutChromeRow(_ row: NSView, arrow: NSTextField, title: NSTextField) {
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(arrow)
        row.addSubview(title)
        NSLayoutConstraint.activate([
            arrow.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            arrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            title.centerXAnchor.constraint(equalTo: row.centerXAnchor),
            title.topAnchor.constraint(equalTo: row.topAnchor),
            title.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            title.leadingAnchor.constraint(greaterThanOrEqualTo: arrow.trailingAnchor, constant: 6),
            title.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor),
        ])
    }

    // `pageCandidates` is the already-sliced set for the current page (≤9), each rendered as a
    // numbered two-column row. `fontSize` is read live from Preferences by the caller so size
    // changes apply without restarting the IME.
    // `hints`, when non-empty, is parallel to `pageCandidates`; a non-nil entry is drawn as a
    // dimmed 倉頡-code hint (反查/拆碼提示) after that row's glyph. An empty array (the default)
    // renders exactly as before.
    func show(_ pageCandidates: [String], page: Int, pageCount: Int, fontSize: CGFloat,
              hints: [String?] = [], near caret: NSRect) {
        let glyphFont = NSFont.systemFont(ofSize: fontSize)
        let numFont = NSFont.monospacedDigitSystemFont(ofSize: Style.numberSize(fontSize), weight: .regular)
        let chromeFont = NSFont.systemFont(ofSize: Style.chromeSize(fontSize), weight: .medium)
        let hintFont = NSFont.systemFont(ofSize: Style.chromeSize(fontSize), weight: .regular)
        for f in [footerArrow, pageLabel] { f.font = chromeFont }

        let para = NSMutableParagraphStyle()
        para.tabStops = [NSTextTab(textAlignment: .left, location: Style.numberColumn(fontSize))]
        para.defaultTabInterval = Style.numberColumn(fontSize)
        para.headIndent = Style.numberColumn(fontSize)
        para.paragraphSpacing = Style.rowGap(fontSize)
        let out = NSMutableAttributedString()
        for (i, cand) in pageCandidates.prefix(9).enumerated() {
            if i > 0 { out.append(NSAttributedString(string: "\n")) }
            out.append(NSAttributedString(
                string: "\(i + 1)\t",
                attributes: [.font: numFont, .foregroundColor: NSColor.secondaryLabelColor]))
            out.append(NSAttributedString(
                string: cand,
                attributes: [.font: glyphFont, .foregroundColor: NSColor.labelColor]))
            // Optional dimmed 倉頡-code hint after the glyph (反查/拆碼提示).
            if i < hints.count, let hint = hints[i], !hint.isEmpty {
                out.append(NSAttributedString(
                    string: "  \(hint)",
                    attributes: [.font: hintFont, .foregroundColor: NSColor.tertiaryLabelColor]))
            }
        }
        out.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: out.length))
        candLabel.attributedStringValue = out
        pageLabel.stringValue = "\(page + 1)/\(pageCount)"

        updateChromeColors()
        panel.setContentSize(stack.fittingSize)
        positionPanel(near: caret)
        panel.orderFront(nil)
    }

    // Layer colours are CGColors and don't auto-adapt to appearance, so resolve them against the
    // current effective appearance each show.
    private func updateChromeColors() {
        content.effectiveAppearance.performAsCurrentDrawingAppearance {
            content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            content.layer?.borderColor = NSColor.labelColor
                .withAlphaComponent(Style.borderAlpha).cgColor
        }
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
