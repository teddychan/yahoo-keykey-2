import Foundation
import DragonKit

// "What's New" content for the current release: a maintenance release, plus the About-pane
// rework that reached users in 2.11.1 without ever being written down. The version is not
// passed — it defaults to CFBundleShortVersionString and the kit adds the "v", so the pane
// cannot claim a release the binary isn't. That makes the entries and the date the only things
// to keep in sync with CHANGELOG.md on release.
//
// 2.11.1 is why the About row is here rather than a release behind. These entries still
// described 2.10.0 while the heading, read from the bundle, already said 2.11.1 — so the pane
// was showing one release's notes under another's number. 2.11.0 was tagged and never released
// (the tag/plist versions disagreed and the build stopped), and 2.11.1 shipped as "a version
// number fix" — but relative to the last release users actually had, 2.10.0, it also carried
// DragonKit v3's fixed-slot About pane. That is described below for the first time.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-10",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .improved, entries: [
                    L("keykey.whatsNew.aboutPane"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.debugBuildIsolation"),
                ]),
            ]
        )
    }
}
