import KeyKeyEngine

// App-internal driving surface shared by both input methods. The IMK
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

// CangjieEngine matches the protocol surface: selectCandidate sets the chosen glyph and
// commit() emits it, so a direct digit-select followed by commit() works.
extension CangjieEngine: InputEngine {}

// SimplexEngine mirrors the CangjieEngine surface exactly (direct digit-select then commit()).
extension SimplexEngine: InputEngine {}
