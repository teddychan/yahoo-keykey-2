import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.14.1 carries an opt-in setting that makes Shift + Space type a full-width space (　) in 倉頡,
// 速成 and 拼音 (issue #135), announced as `.added` — it is off by default. Building it settled
// which character a Shift shortcut commits first: the first one on the page on screen, as Return
// does. 臨時英數 (Shift + letter) took page 1's first even with page 2 showing, so it gets the one
// `.fixed` entry.
//
// These notes were written as 2.14.0, which was never tagged. Its successor's only other change
// (#139) renames the local Debug build and touches nothing a user runs, so it is not announced and
// the 2.14.0 notes ship unchanged as 2.14.1's — the release a 2.13.4 user actually updates to.
//
// Keys are the fleet's stable set (app.whatsNew.summary, .fixed1, .changed1, …), not named after
// this release's content — a release just overwrites the same keys' text in all seven .strings
// files rather than adding new ones and stranding the last release's, which is what happened to
// 2.13.2's `maintenanceOnly` and 2.13.1's `simplexThirdRadical` under the old per-release naming.
// This release has no `.changed` entry, so 2.13.4's `.changed1` is retired from all seven files
// rather than left stranded; `.added1` is new and `.fixed1` carries this release's fix.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-09-27",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("app.whatsNew.added1"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
            ]
        )
    }
}
