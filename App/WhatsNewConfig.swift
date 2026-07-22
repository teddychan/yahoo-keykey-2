import Foundation
import DragonKit

// "What's New" content for the current release (2.7.0). Page Up / Page Down candidate paging,
// a configurable associated-phrase selection key (1–9 vs Shift+1–9), and a fix so ⌘/⌃ shortcuts
// pass through to the app. Keep in sync with CHANGELOG.md on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.7.0",
            date: "2026-07-23",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.paging"),
                    L("keykey.whatsNew.assocKey"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.shortcutPassthrough"),
                ]),
            ]
        )
    }
}
