import Cocoa

// A user-configurable trigger for toggling 中/英 (quick-English) mode. Two kinds:
//   • modifierTap — tap a single modifier alone (the classic Yahoo! KeyKey uses right Shift);
//   • combo       — a non-modifier key plus a modifier mask (e.g. ⇧Space).
// Serialized to a compact string in Preferences so it round-trips across launches.
enum ShortcutSpec: Equatable {
    case modifierTap(Modifier)
    case combo(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)

    // The classic KeyKey default.
    static let `default`: ShortcutSpec = .modifierTap(.rightShift)

    // A tappable modifier, distinguished left/right by hardware key code where it matters.
    enum Modifier: String, CaseIterable {
        case leftShift, rightShift
        case leftControl, rightControl
        case leftOption, rightOption
        case leftCommand, rightCommand
        case capsLock

        // Hardware key code reported on the flagsChanged event for this physical key.
        var keyCode: UInt16 {
            switch self {
            case .leftShift: return 56
            case .rightShift: return 60
            case .leftControl: return 59
            case .rightControl: return 62
            case .leftOption: return 58
            case .rightOption: return 61
            case .leftCommand: return 55
            case .rightCommand: return 54
            case .capsLock: return 57
            }
        }

        // The device-independent flag bit whose presence means "this modifier is down".
        var flag: NSEvent.ModifierFlags {
            switch self {
            case .leftShift, .rightShift: return .shift
            case .leftControl, .rightControl: return .control
            case .leftOption, .rightOption: return .option
            case .leftCommand, .rightCommand: return .command
            case .capsLock: return .capsLock
            }
        }

        var displayString: String {
            switch self {
            case .leftShift: return "⇧ (左)"
            case .rightShift: return "⇧ (右)"
            case .leftControl: return "⌃ (左)"
            case .rightControl: return "⌃ (右)"
            case .leftOption: return "⌥ (左)"
            case .rightOption: return "⌥ (右)"
            case .leftCommand: return "⌘ (左)"
            case .rightCommand: return "⌘ (右)"
            case .capsLock: return "⇪"
            }
        }

        // Map a flagsChanged key code back to the modifier it represents (nil if not a modifier).
        static func from(keyCode: UInt16) -> Modifier? {
            allCases.first { $0.keyCode == keyCode }
        }
    }

    // MARK: Serialization

    var serialized: String {
        switch self {
        case .modifierTap(let m): return "tap:\(m.rawValue)"
        case .combo(let key, let mods): return "combo:\(key):\(mods.rawValue)"
        }
    }

    init?(serialized: String) {
        let parts = serialized.split(separator: ":", omittingEmptySubsequences: false)
        switch parts.first {
        case "tap":
            guard parts.count == 2, let m = Modifier(rawValue: String(parts[1])) else { return nil }
            self = .modifierTap(m)
        case "combo":
            guard parts.count == 3, let key = UInt16(parts[1]), let raw = UInt(parts[2]) else { return nil }
            self = .combo(keyCode: key, modifiers: NSEvent.ModifierFlags(rawValue: raw))
        default:
            return nil
        }
    }

    // MARK: Display

    var displayString: String {
        switch self {
        case .modifierTap(let m):
            return m.displayString
        case .combo(let key, let mods):
            return Self.modifierGlyphs(mods) + Self.keyName(key)
        }
    }

    private static func modifierGlyphs(_ mods: NSEvent.ModifierFlags) -> String {
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option) { s += "⌥" }
        if mods.contains(.shift) { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        return s
    }

    // Best-effort label for the common non-modifier keys used in a toggle combo.
    private static func keyName(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 53: return "⎋"
        case 51: return "⌫"
        default: return "#\(keyCode)"
        }
    }
}
