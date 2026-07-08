import Foundation
import DragonKit

// "What's New" content for the current release (2.6.1). Leads with the new 拼音 (Pinyin)
// input method — added in 2.6.0 but never surfaced in this pane — plus the two 2.6.1 fixes
// (direct number-key selection, pinyin code hint). Keep in sync with CHANGELOG.md on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.6.1",
            date: "2026-07-08",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.pinyin"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.pinyinNumberSelect"),
                    L("keykey.whatsNew.pinyinHint"),
                ]),
            ]
        )
    }
}
