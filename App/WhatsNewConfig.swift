import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.11.6 is maintenance, and unlike 2.11.5 it stayed that way. It bumps the DragonKit pin to
// 4.0.0, a BREAKING kit release that turns the About pane's rows from a convention into the
// initializer's own signature: the licences page is a required argument, and the upstream
// project's repository moved inside OriginalWork so the `Original project` link and the
// `Based on` credit are one value that cannot be supplied by halves.
//
// Nothing on screen moves here, which is the point worth stating rather than dressing up.
// yahoo-keykey-2 was the app that already had all four link rows and the single-holder copyright
// — its own AboutConfig comment is what settled the copyright canon for the other four — so the
// migration was mechanical and the pane it produces is byte-for-byte the arrangement 2.11.2
// shipped. The one visible difference is the DragonKit version the About pane reports.
//
// So: one `.changed` entry, no `.fixed`. Writing this up as a fix would claim a defect this app
// never had, and the honest version of "the shared code now enforces what we were already doing"
// is a single line about the bump. 2.11.3 and 2.11.4 were both a lone `.changed` for the same
// reason.
//
// 2.11.5's language-menu entry is not carried forward, and keykey.whatsNew.languagePicker is
// deleted with it. The pane describes this version, not the accumulated history — that is
// CHANGELOG.md's job.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-11",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("keykey.whatsNew.sharedCode"),
                ]),
            ]
        )
    }
}
