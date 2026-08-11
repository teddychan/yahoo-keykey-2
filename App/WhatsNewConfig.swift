import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.11.5 is maintenance only, and says so. Exactly two commits separate it from 2.11.4: a comment
// in .github/workflows/release.yml naming when the appcast mirror retires, and the DragonKit pin
// moving 3.3.0 -> 3.4.0. Only the second reaches a user at all, and only as the About pane's
// "Built with · DragonKit v3.4.0" row. 3.4.0 adds LanguagePicker(languages:onChange:) with both
// parameters defaulted, which this app never calls — the bump is for pin currency, which
// CONFORMANCE §R10 requires the day the kit tags a release, not to adopt an API. `.changed` and
// not `.fixed` because nothing was broken; not `.improved` because a user gains nothing, the same
// reasoning that chose `.changed` for 2.11.3.
//
// Shipping no entry at all was the other option and is worse. The pane is the only place a user is
// told what a version did, so leaving 2.11.4's text in place would claim the update-feed migration
// a second time, to everyone who already read it. A release that changed nothing a user can use
// still owes the reader the sentence saying so.
//
// 2.11.4's entry is therefore not carried forward. The feed moved once; the pane describes this
// version, not the accumulated history — that is CHANGELOG.md's job.
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
