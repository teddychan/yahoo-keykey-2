import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.14.0 carries one user-facing change: an opt-in setting that makes Shift + Space type a
// full-width space (　) in 倉頡, 速成 and 拼音 (issue #135). Announced as `.added` — it is a new
// setting, off by default, and nothing changes for anyone who leaves it off.
//
// Keys are the fleet's stable set (app.whatsNew.summary, .fixed1, .changed1, …), not named after
// this release's content — a release just overwrites the same keys' text in all seven .strings
// files rather than adding new ones and stranding the last release's, which is what happened to
// 2.13.2's `maintenanceOnly` and 2.13.1's `simplexThirdRadical` under the old per-release naming.
// This release has no `.fixed` or `.changed` entry, so 2.13.4's `.fixed1` and `.changed1` are
// retired from all seven files rather than left stranded, and `.added1` takes their place.
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
            ]
        )
    }
}
