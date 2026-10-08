import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.16.1 keeps 2.16.0's entries and adds one `.fixed` entry: DragonKit 4.1.2's Uninstall stops
// before removing anything when it cannot move an all-users copy, where 2.16.0's cleared the
// settings and then reported "Uninstall Incomplete". The 2.16.0 entries stay because 2.16.0 was
// live for about an hour — nearly everyone updates from 2.15.0 straight to this release and has
// not read them.
//
// 2.16.0 lets KeyKey install itself for all users, in /Library/Input Methods — the one place macOS
// lets a third-party input method through while another app holds secure input. 1Password in
// particular leaves secure input on after a screen lock, which greyed out every KeyKey mode until
// the user quit it (issue #134; known_issues.md #2).
//
// Announced as one `.added` entry for 設定… ▸ 一般 ▸ 為所有使用者安裝…, and two `.changed` entries
// for what moves with it: the Homebrew cask now installs for all users (so brew users are told the
// one command that moves them), and learning pauses while secure input is on — a behaviour change
// a user could otherwise read as the setting silently switching itself off.
//
// Deliberately NOT in the notes: how macOS decides (a path-prefix check inside HIToolbox), how the
// copy is made and verified, and the Sparkle mechanics behind "updates ask for a password" — a user
// meets the button and the password prompt, not the plumbing. CHANGELOG.md and SystemInstall.swift
// record the rest.
//
// Keys are the fleet's stable set (app.whatsNew.summary, .added1, .changed1, …), not named after
// this release's content — a release just overwrites the same keys' text in every locale's .strings
// files rather than adding new ones and stranding the last release's. This release has one `.added`
// entry, so 2.15.0's `.added2` is retired from all seven files rather than left stranded, and
// `.changed2` is new.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-09-28",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("app.whatsNew.added1"),
                ]),
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                    L("app.whatsNew.changed2"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                ]),
            ]
        )
    }
}
