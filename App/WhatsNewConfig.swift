import Foundation
import DragonKit

// "What's New" content for the current release (2.8.0). An option that makes Space confirm the
// typed code in 速成 / 倉頡-with-`*`, and a fix for the 三代 table offering characters under codes
// they do not decompose to. Keep in sync with CHANGELOG.md on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.8.0",
            date: "2026-07-25",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.strokeConfirm"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.cangjieCodes"),
                ]),
            ]
        )
    }
}
