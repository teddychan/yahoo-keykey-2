import KeyKeyEngine

// App-internal driving surface shared by all three input methods. The IMK
// controller's handle() talks to engines only through this protocol; behaviour
// that genuinely differs between methods is branched in handle(), not hidden here.
//
// Contract:
//   - handleKey: feed a typed character; true if the engine consumed it.
//   - composingText: the marked (pre-edit) text to show inline.
//   - candidates: characters/phrases offered for the current composition.
//   - selectCandidate: choose candidates[index] (no-op if out of range).
//   - backspace: edit/delete within the current composition.
//   - commit: finalize the composition, returning the text to insert, and reset.
protocol InputEngine: AnyObject {
    func handleKey(_ key: Character) -> Bool
    var composingText: String { get }
    var candidates: [String] { get }
    func selectCandidate(_ index: Int)
    func backspace()
    func commit() -> String
}

// SmartPhoneticEngine already exposes the exact protocol surface (phrase/Viterbi
// engine; selection is Down-then-digit, then commit() emits the whole phrase).
extension SmartPhoneticEngine: InputEngine {}

// CangjieEngine already matches too: selectCandidate sets the chosen glyph and
// commit() emits it, so a direct digit-select followed by commit() works.
extension CangjieEngine: InputEngine {}

// PlainPhoneticEngine differs: its selectCandidate(_:) returns the chosen single
// character AND resets the engine, so a follow-up commit() would yield nothing.
// This thin adapter captures the selection so commit() returns it instead.
final class PlainPhoneticEngineAdapter: InputEngine {
    private let engine: PlainPhoneticEngine
    private var pendingSelection: String?

    init(_ engine: PlainPhoneticEngine) { self.engine = engine }

    func handleKey(_ key: Character) -> Bool { engine.handleKey(key) }

    var composingText: String { pendingSelection ?? engine.composingText }

    // Once a selection is pending, the composition is effectively finalized: report no
    // candidates so composingText (= pendingSelection) and candidates stay consistent if
    // the IMK loop reads them before commit().
    var candidates: [String] { pendingSelection == nil ? engine.candidates : [] }

    func selectCandidate(_ index: Int) {
        let value = engine.selectCandidate(index)
        pendingSelection = value
    }

    func backspace() {
        pendingSelection = nil
        engine.backspace()
    }

    func commit() -> String {
        if let value = pendingSelection {
            pendingSelection = nil
            return value
        }
        return engine.commit()
    }
}
