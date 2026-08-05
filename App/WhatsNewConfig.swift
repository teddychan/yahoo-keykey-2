import Foundation
import DragonKit

// "What's New" content for the current release (2.9.1). A single fix: the candidate / 聯想
// window no longer stays on screen after the input session ends. Keep in sync with CHANGELOG.md
// on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.9.1",
            date: "2026-08-05",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.strandedWindow"),
                ]),
            ]
        )
    }
}
