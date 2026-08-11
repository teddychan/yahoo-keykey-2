import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.12.1 claims one fix: `App/Info.plist` had no `NSHumanReadableCopyright`, so Finder's Get Info
// panel showed no copyright line for Yahoo! KeyKey 2 at all. It now carries `© 2026 Teddy Chan` —
// byte-for-byte the string the About pane's copyright row renders.
//
// Found by auditing the field across all five Dragon apps, where it was in four different states:
// a tagline in clipmenu-2, two holders in ice-2, and absent here, in spectacle-2 and in the sample
// app. KeyKey is the app whose About copyright slot once held `倉頡／簡易 輸入法` — the defect
// DragonKit still cites in `DragonAbout.copyright(years:holder:)` — so having the bundle's own
// notice missing entirely was the same failure one field over. The key is an optional Apple one
// that no licence names, so it is presentation, and the rule for presentation is the one About
// already follows: a single holder, the app's own.
//
// `.fixed`, not `.added`. A bundle is expected to carry this field; the app shipped without it.
//
// Deliberately NOT in the notes: LICENSE's holder changes from "Lung Sang Chan (teddychan)" to
// "Teddy Chan", so all five apps name the holder one way. That is the same person either way and
// nothing a user can observe from inside the app — CHANGELOG.md carries it.
//
// `keykey.whatsNew.allLanguages` is gone, replaced in place by `keykey.whatsNew.copyrightNotice`
// in all seven .strings files. 2.12.0's `.added` entry has nothing to say here, and leaving the
// key behind would strand that release's sentence in seven files waiting to be shown again.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-11",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.copyrightNotice"),
                ]),
            ]
        )
    }
}
