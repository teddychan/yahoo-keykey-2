import SwiftUI
import AppKit

// A minimal shortcut recorder for the 中/英 toggle. Click to start recording, then either tap
// a single modifier (captured as a modifier-tap, e.g. right Shift) or press a modifier+key
// combo (e.g. ⇧Space). A bare key with no modifier is rejected (it would swallow that key
// everywhere). Esc cancels recording without changing the current shortcut.
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var spec: ShortcutSpec

    func makeNSView(context: Context) -> RecorderNSView {
        let v = RecorderNSView()
        v.spec = spec
        v.onChange = { newSpec in
            // Hop out of the AppKit event callback before mutating SwiftUI state.
            DispatchQueue.main.async { self.spec = newSpec }
        }
        return v
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.spec = spec
        nsView.needsDisplay = true
    }

    final class RecorderNSView: NSView {
        var spec: ShortcutSpec = .default
        var onChange: ((ShortcutSpec) -> Void)?
        private var recording = false

        override var acceptsFirstResponder: Bool { true }
        override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 24) }

        override func draw(_ dirtyRect: NSRect) {
            let radius: CGFloat = 6
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                    xRadius: radius, yRadius: radius)
            (recording ? NSColor.controlAccentColor.withAlphaComponent(0.15)
                       : NSColor.controlBackgroundColor).setFill()
            path.fill()
            (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.lineWidth = 1
            path.stroke()

            let text = recording ? "按下按鍵…" : spec.displayString
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: recording ? NSColor.controlAccentColor : NSColor.labelColor,
                .paragraphStyle: style,
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            let rect = NSRect(x: 0, y: (bounds.height - size.height) / 2,
                              width: bounds.width, height: size.height)
            (text as NSString).draw(in: rect, withAttributes: attrs)
        }

        override func mouseDown(with event: NSEvent) {
            recording = true
            window?.makeFirstResponder(self)
            needsDisplay = true
        }

        override func resignFirstResponder() -> Bool {
            recording = false
            needsDisplay = true
            return true
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            if event.keyCode == 53 { // Esc cancels
                stopRecording()
                return
            }
            let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
            guard !mods.isEmpty else {
                NSSound.beep() // a bare key would swallow that key everywhere — reject it
                return
            }
            commit(.combo(keyCode: event.keyCode, modifiers: mods))
        }

        override func flagsChanged(with event: NSEvent) {
            guard recording else { super.flagsChanged(with: event); return }
            guard let modifier = ShortcutSpec.Modifier.from(keyCode: event.keyCode),
                  event.modifierFlags.contains(modifier.flag) else { return } // capture on press only
            commit(.modifierTap(modifier))
        }

        private func commit(_ newSpec: ShortcutSpec) {
            spec = newSpec
            onChange?(newSpec)
            stopRecording()
        }

        private func stopRecording() {
            recording = false
            window?.makeFirstResponder(nil)
            needsDisplay = true
        }
    }
}
