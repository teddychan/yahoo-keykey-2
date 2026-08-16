import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.13.1 claims one fix, from issue #113.
//
// `.fixed` is 速成 no longer building a code it cannot resolve. A 速成 code is the 倉頡 first + last
// radical, so it is two keys at most — but SimplexEngine.handleKey had no length limit, and the key
// that starts the NEXT character was appended to the code just finished. The resulting 3-key code
// is in no 速成 table, so the candidate list emptied and the character the user had already
// finished could not be selected at all; Backspace was the only way out. A third radical now
// commits the character in progress and begins the next one with that key, which is what the
// original Yahoo! KeyKey does.
//
// Deliberately NOT in the notes: the DragonKit pin moving to 4.1.0. 2.11.5 and 2.11.6 each carried
// a pin entry because the bump WAS the substance of those releases; here it is a conformance-driven
// follow, it needed no App/ change, and the only thing a user could see is the version the About
// pane reports. CHANGELOG.md records it either way.
//
// The 2.13.0 keys (`adaptiveCandidateOrder`, `associationOrderStable`) are gone from all seven
// .strings files, replaced by the key below — the same treatment `copyrightNotice` got when 2.13.0
// superseded 2.12.1. Leaving a superseded key behind strands that release's sentence in seven files
// waiting to be shown again.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-16",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.simplexThirdRadical"),
                ]),
            ]
        )
    }
}
