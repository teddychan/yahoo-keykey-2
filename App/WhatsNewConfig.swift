import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.11.3 is maintenance only, and says so. It publishes the update feed to this repository as
// well as the website, so a problem with the website can no longer hold up an update, and it
// makes the engine's learning-store directory a required argument rather than one defaulting to
// the release location. Neither is observable: the copy you have installed keeps reading the
// website until 2.11.4 moves it, and every caller already named its directory. `.changed` and
// not `.fixed`, because nothing was broken.
//
// 2.11.2's two entries are gone rather than carried forward. One of them was a catch-up — the
// About-pane rework reached users in 2.11.1 as "a version number fix" and was described for the
// first time in 2.11.2 — and a catch-up that has been shown has done its job. Repeating it would
// re-announce it to everyone who already read it.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-11",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("keykey.whatsNew.updateFeed"),
                ]),
            ]
        )
    }
}
