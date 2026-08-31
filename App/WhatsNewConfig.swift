import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.13.4 carries one user-facing change: a character the built-in dictionary does not know can now
// be learned to the front of the candidate list. It could not before — it climbed past the other
// unknown characters and then stopped behind the known ones permanently (issue #130).
//
// One `.fixed` entry and no `.changed`, which is the whole release. The note has to do two jobs at
// once: say the thing that was broken now works, and warn that a list someone has already trained
// may look different today, because that is a visible change nobody asked for. An untrained list
// is unchanged, so the warning is scoped to people the change can actually reach.
//
// Deliberately NOT in the notes: that the fix is a single constant in the two engines' sort score.
// A user meets the ordering, not the floor — CHANGELOG.md and the 2026-08-12 spec carry the
// mechanism and the measurements.
//
// Keys are the fleet's stable set (app.whatsNew.summary, .fixed1, .changed1, …), not named after
// this release's content — a release just overwrites the same keys' text in all seven .strings
// files rather than adding new ones and stranding the last release's, which is what happened to
// 2.13.2's `maintenanceOnly` and 2.13.1's `simplexThirdRadical` under the old per-release naming.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-31",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                    // The trained-list caveat, kept as its own entry rather than folded into the
                    // one above. It is the only part of this release a user has to act on — and
                    // only some users — so burying it at the end of a paragraph about a fix would
                    // hide the sentence that explains why their candidates moved.
                    L("app.whatsNew.fixed2"),
                ]),
            ]
        )
    }
}
