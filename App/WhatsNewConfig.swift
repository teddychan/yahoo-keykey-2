import Foundation
import DragonKit

// "What's New" content for the current release (2.2.0), mirroring CHANGELOG.md's top entry:
// z-code punctuation in 三代倉頡, and the 聯想只顯示接續字 option.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.2.0",
            date: "2026-07-05",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.zcode"),
                    L("keykey.whatsNew.continuationOnly"),
                ]),
            ]
        )
    }
}
