import Foundation
import DragonKit

// "What's New" content for the current release (2.6.2). A small tidy-up: the coarse 候選字大小
// (小／中／大) shortcuts were removed from the input menu now that Settings has a fine-grained
// size slider. Keep in sync with CHANGELOG.md on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.6.2",
            date: "2026-07-08",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("keykey.whatsNew.candidateSizeMenu"),
                ]),
            ]
        )
    }
}
