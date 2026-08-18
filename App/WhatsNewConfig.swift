import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.13.2 claims one `.changed`, and it is a maintenance release: **no App/ source changed at all**.
// `git diff v2.13.1..main` over the release is three files — .github/workflows/release.yml,
// README.md and docs/yahoo-keykey-2/appcast.xml — and not one .swift among them. The DragonKit pin
// is still v4.1.0. So the honest note says exactly that: release automation and documentation, with
// typing untouched.
//
// `.changed` rather than `.fixed` or `.improved` because nothing in the app was broken and nothing
// in it got better; what moved sits around the app. There is no kind for "nothing you can see", and
// inventing a user-facing change to fill the slot is the one thing this pane must never do.
//
// The notes MOVE because the release gate requires it — it diffs WhatsNewConfig.swift and all seven
// .strings against the previous tag, so a release cannot ship its predecessor's text. That is a
// requirement to rewrite the notes, not a licence to claim a change: the gate is satisfied by
// truthfully describing a maintenance release.
//
// 2.13.1's `simplexThirdRadical` key is gone from all seven .strings files, replaced by the key
// below — the same treatment 2.13.0's keys got when 2.13.1 superseded them. Leaving a superseded key
// behind strands that release's sentence in seven files waiting to be shown again.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-18",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("keykey.whatsNew.maintenanceOnly"),
                ]),
            ]
        )
    }
}
