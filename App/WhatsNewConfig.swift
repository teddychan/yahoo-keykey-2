import Foundation
import DragonKit

// "What's New" content for the current release: VoiceOver support for the candidate window,
// optimized builds, a real menu bar in Settings, and four fixes. The version is not passed — it
// defaults to CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a
// release the binary isn't. That makes the entries and the date the only things to keep in sync
// with CHANGELOG.md on release.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
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
