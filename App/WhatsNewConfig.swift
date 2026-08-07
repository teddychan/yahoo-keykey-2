import Foundation
import DragonKit

// "What's New" content for the current release (2.10.0): VoiceOver support for the candidate
// window, optimized builds, a real menu bar in Settings, and four fixes. Keep in sync with
// CHANGELOG.md on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: "2.10.0",
            date: "2026-08-07",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.voiceOver"),
                ]),
                ChangeSection(kind: .improved, entries: [
                    L("keykey.whatsNew.speed"),
                    L("keykey.whatsNew.settingsMenuBar"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.backupRestore"),
                    L("keykey.whatsNew.uninstallReport"),
                    L("keykey.whatsNew.cangjieVersionMix"),
                    L("keykey.whatsNew.learningFile"),
                ]),
            ]
        )
    }
}
