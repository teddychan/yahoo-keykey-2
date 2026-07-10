import Foundation
import DragonKit

// "What's New" content for the current release (2.6.4). Performance + robustness: single-pass
// dictionary load, lazily-built 速成 table / 反查 index, and a 拼音 composer that stays responsive
// on unusual input. Keep in sync with CHANGELOG.md on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.6.4",
            date: "2026-07-10",
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
