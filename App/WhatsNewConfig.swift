import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.16.2 brings 注音's candidate keys in line with the original Yahoo! KeyKey's ㄅ半 and
// McBopomofo's Plain Bopomofo (issue #148): a number with no candidate on its row types 注音 — on
// 大千 that is ㄅ ㄉ ㄓ ㄚ ㄞ, the start of 不, 的, 這 — instead of being swallowed, and a reading
// with only one character commits as soon as its tone lands.
//
// Announced as one `.changed` entry (the window no longer opens for a single candidate, which a
// typist notices) and one `.fixed` entry (the swallowed number key). Both name 注音,
// because nothing changes for 倉頡, 速成 or 拼音.
//
// Deliberately NOT in the notes: that bare 1–9 still picks whenever its row has a candidate, the
// way both originals do — that is unchanged behaviour, and README.md says it.
//
// Keys are the fleet's stable set (app.whatsNew.summary, .added1, .changed1, …), not named after
// this release's content — a release just overwrites the same keys' text in all seven .strings
// files rather than adding new ones and stranding the last release's. This release has no `.added`
// entry and one `.changed`, so 2.16.x's `.added1` and `.changed2` are retired from all seven files
// rather than left stranded.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-10-08",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
            ]
        )
    }
}
