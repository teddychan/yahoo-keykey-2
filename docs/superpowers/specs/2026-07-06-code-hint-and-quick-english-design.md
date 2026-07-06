# Design: 反查/拆碼提示 (Cangjie code hint) + 臨時英數 (quick English)

Two KeyKey gap-closing features for Yahoo KeyKey 2. Built sequentially on one branch:
Feature 1 first (self-contained, low risk), then Feature 2.

## Feature 1 — 反查/拆碼提示 (Cangjie code hint) · default OFF

### Goal
In the candidate window, show each single character's full 倉頡 code as dimmed radical
glyphs after the glyph, e.g. `1  倉  人戈日口`. A learning/verification aid — especially
useful in 速成 (you type only first+last radical) and 聯想 (you don't type a code at all).

### Design
- **`CangjieCodeIndex`** (new, `Packages/KeyKeyEngine/Sources/KeyKeyEngine/CangjieCodeIndex.swift`):
  built from a `CangjieTable` by iterating `forEachEntry`. For each character keep the
  **shortest** code (ties broken by lexicographic order for determinism). Exposes
  `codeGlyphs(for character: Character) -> String?` returning the code letters mapped
  through the inverse of `CangjieEngine.radicals` (e.g. `"orhr"` → `"人口竹口"`). Returns
  `nil` for characters not in the table.
- **`SharedResources`** owns one `CangjieCodeIndex`, (re)built inside `loadCangjieTables`
  from the just-loaded `cangjieTable`, so it always matches the selected 五代/三代 table
  and rebuilds on a 倉頡版本 change (existing `reloadCangjieTables` path).
- **`CandidateWindow.show`** gains an optional trailing param `hints: [String?] = []`
  parallel to `pageCandidates`. When a row's hint is non-nil/non-empty it is appended to
  that row as a smaller (`chromeSize`) `secondaryLabelColor` run after a couple of spaces.
  Empty `hints` (the default) reproduces today's exact rendering.
- **`InputController.refresh`** builds `hints` only when `Preferences.codeHintEnabled`:
  - for engine (Cangjie/Simplex) candidates → `codeIndex.codeGlyphs(for:)` of each
    single-character candidate (nil for multi-scalar/absent);
  - for 聯想 rows → hint only when the *displayed* string is a single character (i.e.
    continuation-only mode, or a single-char association); whole words get `nil`.
  - When code hint is disabled, pass `[]` so behaviour/layout is byte-for-byte unchanged.
- **Preference** `codeHintEnabled: Bool` (registered default **false**) in `Preferences`,
  surfaced as an input-menu checkbox (`反查提示`) and a `GeneralPane` toggle via
  `SettingsModel`. Read live like the other toggles (no restart).

### Files touched (Feature 1)
`CangjieCodeIndex.swift` (new) · `SharedResources.swift` · `CandidateWindow.swift` ·
`InputController.swift` · `Preferences.swift` · `SettingsModel.swift` · `GeneralPane.swift`
· `App/*.lproj/Localizable.strings`.

### Tests (Feature 1)
Engine-level XCTest `CangjieCodeIndexTests` in `Packages/KeyKeyEngine/Tests`:
- shortest-code selection when a char has multiple codes;
- letters→radical-glyph mapping;
- `nil` for an absent character;
- determinism of the tie-break.

## Feature 2 — 臨時英數 (quick English) · default toggle = Right-Shift tap

### Goal
Type English/ASCII without switching the system input source. A persistent **中/英 mode**;
the toggle shortcut flips it (committing any active composition first). In 英 mode every key
passes through to the app as raw ASCII (full-width punctuation bypassed). The toggle shortcut
is **user-customizable**, defaulting to the classic KeyKey **Right-Shift tap**.

### Design
- **`ShortcutSpec`** (new value type, App target): represents either
  1. a **modifier-only tap** — one of Right-Shift, Left-Shift, ⌃, ⌥, ⌘, Right-⌘, Caps Lock; or
  2. a **modifier+key combo** — a non-modifier key plus a modifier mask (e.g. ⇧Space).

  Serializes to/from a compact string stored in `Preferences.englishToggleShortcut`.
  A human-readable `displayString` for the recorder UI. Default value = Right-Shift tap.
  Left/Right Shift are distinguished via `NSEvent` key-code on flagsChanged
  (60 = right-shift, 56 = left-shift; likewise 54/55 for right/left ⌘).
- **`englishMode`** is in-memory shared state on `SharedResources` so every
  `InputController` instance (IMK makes one per client app) agrees. **Not persisted** —
  starts 中 on each launch.
- **`InputController`**:
  - `recognizedEvents` adds `.flagsChanged` to the mask.
  - **Modifier-tap detection:** on a `flagsChanged` where the target modifier turns *on*,
    record it as "armed" and that no keyDown has since occurred; on the matching turn-*off*
    flagsChanged, if still armed and nothing intervened, fire the toggle. Any keyDown or a
    second modifier disarms it (so Shift-as-capital never toggles). Right-vs-left shift
    resolved by `event.keyCode` on the flagsChanged.
  - **Combo detection:** in the keyDown path, if the event matches the configured combo
    spec, fire the toggle and consume the key.
  - **Toggle action:** commit any active composition (`commitCurrent`), flip
    `SharedResources.englishMode`, hide the candidate window.
  - **英 mode behaviour:** at the top of `handle()` (after toggle checks), if
    `englishMode` is on, return `false` for every normal key so the client receives raw
    ASCII; the full-width-punctuation branch and engine feed are skipped.
  - Add a **中/英 menu checkbox** (`英文輸入`) as a discoverable, no-shortcut fallback.
- **`ShortcutRecorderView`** (new, App target): a minimal `NSViewRepresentable` wrapping an
  AppKit view that becomes first responder on click, captures the next tap/combo into a
  `ShortcutSpec`, and shows its `displayString`. A "重設" button resets to Right-Shift.
- **UI:** `SettingsModel` exposes the shortcut + a binding; `GeneralPane` adds a
  "中/英 切換快速鍵" row with the recorder and reset. Strings localized.

### Files touched (Feature 2)
`ShortcutSpec.swift` (new) · `ShortcutRecorderView.swift` (new) · `InputController.swift` ·
`SharedResources.swift` (englishMode flag) · `Preferences.swift` · `SettingsModel.swift` ·
`GeneralPane.swift` · `App/*.lproj/Localizable.strings`.

### Testing (Feature 2)
`ShortcutSpec` serialization/round-trip + `displayString` are pure. The `.flagsChanged` tap
disambiguation is IMK-runtime behaviour — verified via a **manual test checklist**:
(a) Right-Shift tap flips 中/英; (b) Shift+letter still types a capital and does NOT toggle;
(c) an active composition commits on toggle; (d) 英 mode passes ASCII through and bypasses
full-width punctuation; (e) a custom combo (e.g. ⇧Space) toggles; (f) reset restores
Right-Shift.

## Build order & risk
1. **Feature 1** — engine index (TDD) → candidate rendering → prefs/UI. Low risk.
2. **Feature 2** — `ShortcutSpec` → controller `.flagsChanged`/mode logic → recorder UI.
   Main risk: Shift-tap misfiring; mitigated by strict disarm-on-keyDown and the manual
   checklist above.

Verification: `swift test` for the KeyKeyEngine package; full app build via
`tools/build-app.sh` (clones pinned DragonKit) to confirm the App target compiles.

## Non-goals
- No on-screen HUD for the mode flip (feedback = menu checkmark + behaviour).
- 中/英 mode is not persisted across relaunches.
- Code hint applies to single characters only (no per-word decomposition for 聯想 phrases).
