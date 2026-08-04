import Foundation
import DragonKit

// "What's New" content for the current release (2.9.0). The input menu's app items now come
// from DragonKit's shared DragonAppMenu (canonical macOS naming, each with a leading SF Symbol),
// and Uninstall has moved out of the input menu into Settings. Keep in sync with CHANGELOG.md
// on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.9.0",
            date: "2026-08-05",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("keykey.whatsNew.sharedMenu"),
                    L("keykey.whatsNew.uninstallInSettings"),
                ]),
            ]
        )
    }
}
