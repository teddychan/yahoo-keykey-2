import Foundation
import DragonKit

// "What's New" content for the current release (2.4.0), mirroring CHANGELOG.md's top entry:
// the 反查／拆碼提示 (Cangjie code hint) and 臨時英數 (quick English) features, plus the
// 倉頡版本-save fix.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.4.0",
            date: "2026-07-06",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.codeHint"),
                    L("keykey.whatsNew.quickEnglish"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.cangjieVersionFix"),
                ]),
            ]
        )
    }
}
