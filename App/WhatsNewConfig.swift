import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.11.4 is maintenance only, and says so. It completes what 2.11.3 began: SUFeedURL now points
// at this repository's copy of the appcast rather than the website's, so update delivery no
// longer depends on the marketing site being deployed and current. Not observable — updates keep
// arriving, from the same signing key, at the same cadence — so `.changed` and not `.fixed`.
//
// The order was load-bearing. 2.11.3 published to BOTH while every installed copy still read the
// website; only once that had actually run did the app-owned feed exist to be pointed at. Doing
// both in one release would have sent every install to a 404.
//
// 2.11.2's entries are not carried forward. One was a catch-up — the About-pane rework reached
// users in 2.11.1 as "a version number fix" and was described for the first time in 2.11.2 — and
// a catch-up that has been shown has done its job.
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
