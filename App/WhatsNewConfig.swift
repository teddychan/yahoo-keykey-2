import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.13.3 carries one user-facing change, inherited from DragonKit 4.1.1: Uninstall now refuses to
// run when it finds more than one copy of the app on the Mac. Settings, the login item, support
// files and the Homebrew record are all keyed to the app's identity rather than its location, so
// two copies share all of them and there is no way to tell whose is whose — uninstalling a spare
// copy could remove the settings belonging to the copy you actually use. It now stops before
// removing anything and lists where the copies are.
//
// Deliberately NOT in the notes: DragonKit 4.1.1's other fix, a raw developer error in Settings ▸
// Updates. It only ever appeared in local debug builds, so no released build of Yahoo! KeyKey 2
// could hit it — CHANGELOG.md records it, this pane does not, following the fleet's rule against
// claiming what users cannot see.
//
// Keys are the fleet's stable set (app.whatsNew.summary, .fixed1, .changed1, …), not named after
// this release's content — a release just overwrites the same keys' text in all seven .strings
// files rather than adding new ones and stranding the last release's, which is what happened to
// 2.13.2's `maintenanceOnly` and 2.13.1's `simplexThirdRadical` under the old per-release naming.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-20",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                    // The rename to "Yahoo! KeyKey 2". Announced because it is the name macOS
                    // shows in the Input Sources picker, so a user meets it — 2.13.3's notes were
                    // written before the rename landed, which is the only reason it was missing.
                    // `.changed`, not `.fixed`: nothing was broken, the mark was simply absent.
                    L("app.whatsNew.changed2"),
                ]),
            ]
        )
    }
}
