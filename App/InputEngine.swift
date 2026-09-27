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
//   - pendingUsage: the candidate-list usage a commit would credit, valid only BEFORE commit().
protocol InputEngine: AnyObject {
    func handleKey(_ key: Character) -> Bool
    var composingText: String { get }
    var candidates: [String] { get }
    func selectCandidate(_ index: Int)
    func backspace()
    func commit() -> String
    /// What committing right now would credit to the adaptive-ordering store: the candidate about
    /// to be committed, paired with the identity of the list it is being picked from.
    ///
    /// Part of the protocol so no engine can be driven by `handle()` without answering it, and
    /// read BEFORE `commit()` at the single call site that inserts into the client — `commit()`
    /// clears the code/nodes this is derived from, so afterwards it is empty. Empty is also the
    /// honest answer for a list with nothing to reorder.
    var pendingUsage: [CandidateUsage] { get }
}

// CangjieEngine matches the protocol surface: selectCandidate sets the chosen glyph and
// commit() emits it, so a direct digit-select followed by commit() works.
extension CangjieEngine: InputEngine {}

// SimplexEngine mirrors the CangjieEngine surface exactly (direct digit-select then commit()).
extension SimplexEngine: InputEngine {}

// ZhuyinEngine (注音/ㄅ半) is a single-character engine like the two above — one syllable, one
// character, digit-select then commit() — so it needs nothing beyond this surface. The two rules
// that are its own (Space is the first-tone key; a 注音 key against a finished syllable starts the
// next character) are methods the controller reaches through a cast, exactly as it does for
// SimplexEngine.keyStartsNewComposition, because both must commit into the client and only the
// controller can do that.
extension ZhuyinEngine: InputEngine {}

// Richer surface for phrase-composition engines (Pinyin): an editable multi-node buffer
// with a node cursor. The IMK controller detects this protocol to route cursor movement
// and per-node candidate selection. Cangjie/Simplex do NOT conform (single-char engines).
protocol PhraseComposingEngine: InputEngine {
    func moveCursorLeft() -> Bool
    func moveCursorRight() -> Bool
    // Pinyin reading of the node under the cursor (e.g. "wo", "ni hao"), for the code hint.
    var cursorReading: String? { get }
}

// PinyinEngine already exposes the full InputEngine surface plus cursor movement, except
// `pendingUsage`: 拼音 candidate ranking is deliberately OUT of the per-list adaptive-ordering
// change, so it credits nothing to that store and keeps ranking off the per-character store it
// always used (see UserFrequency and InputController.userRank). Empty here is the honest answer —
// not a stub — and it keeps the single commit call site uniform across every engine.
extension PinyinEngine: InputEngine {
    var pendingUsage: [CandidateUsage] { [] }
}
extension PinyinEngine: PhraseComposingEngine {}
