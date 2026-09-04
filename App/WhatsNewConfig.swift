import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.13.4 carries one user-facing change: adaptive candidate ordering is now decided by how often
// you commit each candidate in its own candidate list, so picking a rare character puts it in
// front of everything you have not picked — including characters the built-in dictionary has
// never heard of, which it previously could never overtake at any number of picks (issue #130).
//
// Announced as `.fixed`, because what a user meets is a behaviour that was reported as broken,
// with one `.changed` entry for the consequence they will notice on first launch: the learning
// history starts fresh. The retired store held one count per character with no record of which
// list it was committed in, and there is no honest way to turn that into per-list history, so it
// is left on disk untouched rather than reinterpreted.
//
// Deliberately NOT in the notes: that the per-list store is a new file, its bounds, and the
// internals of the ordering rule. A user meets the behaviour, not the storage — CHANGELOG.md
// records the rest, following the fleet's rule against announcing what users cannot see.
//
// Keys are the fleet's stable set (app.whatsNew.summary, .fixed1, .changed1, …), not named after
// this release's content — a release just overwrites the same keys' text in all seven .strings
// files rather than adding new ones and stranding the last release's, which is what happened to
// 2.13.2's `maintenanceOnly` and 2.13.1's `simplexThirdRadical` under the old per-release naming.
// 2.13.3 used a `.changed2` for the rename to "Yahoo! KeyKey 2"; this release has only one
// `.changed` to make, so that key is retired from all seven files rather than left stranded.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-09-04",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
            ]
        )
    }
}
