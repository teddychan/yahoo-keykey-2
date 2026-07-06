import Foundation
import DragonKit

// "What's New" content for the current release (2.3.0), mirroring CHANGELOG.md's top entry:
// refreshed settings/app screens (built on the shared DragonKit UI), a new Sync & Backup
// screen, and live in-app language switching.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.3.0",
            date: "2026-07-06",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.backup"),
                    L("keykey.whatsNew.language"),
                ]),
                ChangeSection(kind: .changed, entries: [
                    L("keykey.whatsNew.redesign"),
                ]),
            ]
        )
    }
}
