import Foundation
import DragonKit

// "What's New" content for the current release (2.6.3). Performance-only: lower launch memory /
// faster startup, and less per-keystroke work while typing 拼音. Keep in sync with CHANGELOG.md
// on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.6.3",
            date: "2026-07-09",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("keykey.whatsNew.perfMemory"),
                    L("keykey.whatsNew.perfPinyin"),
                ]),
            ]
        )
    }
}
