import Foundation
import DragonKit

// "What's New" content for the current release. The version is not passed — it defaults to
// CFBundleShortVersionString and the kit adds the "v", so the pane cannot claim a release the
// binary isn't. That makes the entries and the date the only things to keep in sync with
// CHANGELOG.md on release.
//
// 2.13.0 claims one addition and one fix, both from issue #85.
//
// `.added` is the 依選字習慣調整候選字順序 toggle. Yahoo! KeyKey 2 has always counted the characters
// you commit and ranked candidates by that count, with no way to stop it. The issue is from a
// long-time 速成 typist who had memorised the candidate sequence: for them a list that keeps
// rearranging itself is worse than one that never moves, because the position they reach for is no
// longer the position the character is in. On by default, so nobody's existing install changes.
//
// `.fixed` is the 聯想 ordering becoming reproducible. It is a real user-visible change and not
// merely internal: `AssociatedPhrases` sorted on score alone through Swift's `sorted(by:)`, which
// is not stable, so equal-scoring phrases sat in an arbitrary order — and because that same sort
// feeds the 20-per-bucket cap, the arbitrariness decided which suggestions the user could ever see.
// It is in this release rather than its own because making 聯想 frequency-ranked is what moved the
// ordering from load time to query time; a promise that the order "does not change based on your
// selections" is only true if the order is reproducible to begin with.
//
// Deliberately NOT in the notes: the learning store, the 20-per-bucket cap and the What's New
// mechanism itself are all unchanged, and the seven .strings files gain the setting's own two
// strings, which the General pane shows rather than this pane.
//
// `keykey.whatsNew.copyrightNotice` is gone, replaced by the two keys below in all seven .strings
// files. 2.12.1's entry has nothing to say here, and leaving the key behind would strand that
// release's sentence in seven files waiting to be shown again.
enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            date: "2026-08-12",
            summary: L("keykey.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("keykey.whatsNew.adaptiveCandidateOrder"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("keykey.whatsNew.associationOrderStable"),
                ]),
            ]
        )
    }
}
