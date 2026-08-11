import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.12.0 adds the five localizations KeyKey did not have: App/{es,fr,ja,ko,zh-Hans}.lproj, beside
// the en and zh-Hant it shipped with. One `.added` entry, because that is the whole of what a user
// can notice.
//
// This closes 2.11.5 from the other side. That release NARROWED the Language menu to [.en, .zhHant]
// because the bare LanguagePicker() took the kit's default of all seven locales while KeyKey had
// two, so choosing one of the other five translated the shared panes and left every KeyKey string
// in English. Narrowing was the honest fix for a two-language app; translating the app is the fix
// that lets the menu open back up. App/GeneralPane.swift is bare again as a result, and it is bare
// rather than a literal list of seven on purpose — see the comment there.
//
// Deliberately NOT in the notes: this release also drops appcast_mirror_repo from
// .github/workflows/release.yml, the step-3 retirement that file has been committed to since
// 2.11.3 and that names the next MINOR release as its trigger — 2.11.6 was a patch and correctly
// left it alone; this is the release the trigger meant. It is invisible either way, since
// installed copies have read the app-owned feed since 2.11.4, and the notes describe what a user
// can see. CHANGELOG.md carries it as an under-the-hood line.
//
// The DragonKit pin does not move here — 2.11.6 already took it to 4.0.0 — so there is no
// `.changed` for it, and `keykey.whatsNew.sharedCode` is deleted with that release's entry. 2.11.5
// and 2.11.6 both carried a pin entry because the bump was the substance of those releases;
// repeating it every time is the padding those entries avoided.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-11",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.allLanguages"),
                ]),
            ]
        )
    }
}
