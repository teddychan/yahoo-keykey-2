import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.15.0 adds an input method: 注音 (ㄅ半), the classic one-syllable-one-character phonetic
// method, with a choice of 標準（大千）or 倚天 keyboard.
//
// Announced as `.added` — a whole method is the release — with one `.changed` entry for the two
// keys that behave differently in 注音 and would otherwise read as bugs: `,` and `.` type ㄝ and
// ㄡ (so ，。 move to their shifted forms), and 聯想字詞 needs Shift + a number because the number
// row types 注音. Both are scoped to 注音; nothing changes for 倉頡, 速成 or 拼音, which is what
// the entry says, because an existing user's first question about a release that adds a mode is
// whether their own mode moved.
//
// Deliberately NOT in the notes: which table the candidates come from, how the readings are keyed,
// and that the table loads on first use. A user meets the typing, not the data pipeline —
// CHANGELOG.md and Resources/ZHUYIN-DATA-LICENSE.txt record the rest, following the fleet's rule
// against announcing what users cannot see. 2.14.1's Shift + Space notes are that release's own
// and are not repeated here.
//
// Keys are the fleet's stable set (app.whatsNew.summary, .added1, .changed1, …), not named after
// this release's content — a release just overwrites the same keys' text in all seven .strings
// files rather than adding new ones and stranding the last release's. This release has no `.fixed`
// entry, so 2.14.1's `.fixed1` is retired from all seven files rather than left stranded; `.added2`
// is new, and `.changed1` returns with this release's text.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-09-27",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("app.whatsNew.added1"),
                    L("app.whatsNew.added2"),
                ]),
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
            ]
        )
    }
}
