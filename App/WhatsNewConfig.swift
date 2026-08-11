import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.11.5 started as maintenance — a DragonKit pin bump for currency and a CI comment — and stopped
// being maintenance when the bump turned out to fix a live bug. So the notes lead with the fix,
// `.fixed`, and the bump follows as `.changed`. Getting this wrong in the safe-looking direction
// (shipping the maintenance-only wording that was already written) would have hidden the only
// thing in the release a user can actually notice.
//
// The bug: App/GeneralPane.swift called LanguagePicker with no argument, so it took the kit's
// default of DragonLanguage.selectable — all seven locales DragonKit ships — while KeyKey has
// translated itself into two, App/en.lproj and App/zh-Hant.lproj. Settings therefore offered
// Español, Français, 日本語, 한국어 and 简体中文, and choosing one translated the kit's four panes
// and nothing else. `.fixed` and not `.changed`: the menu was making an offer the app could not
// keep.
//
// The `languages:` argument that fixes it is new in DragonKit 3.4.0, which is what this release
// bumps the pin to — so the two entries are one story, and the second earns its place by being the
// reason the first is possible rather than by padding the list.
//
// Worth saying in the notes and not only here: the kit appends an out-of-set selection to the
// picker (LanguagePicker.offeredLanguages), so a user who had already chosen 日本語 still sees it
// listed and can move off it. Narrowing the list would otherwise orphan their choice, and SwiftUI
// draws a Picker whose selection matches no tag as blank.
//
// 2.11.4's entry is not carried forward. The feed moved once; the pane describes this version, not
// the accumulated history — that is CHANGELOG.md's job.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-11",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.languagePicker"),
                ]),
                ChangeSection(kind: .changed, entries: [
                    L("keykey.whatsNew.sharedCode"),
                ]),
            ]
        )
    }
}
