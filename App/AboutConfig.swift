import Foundation
import DragonKit

// About-pane content. DragonKit v3 owns every row title, SF Symbol and ordering — this file
// supplies only URLs and proper nouns, so the pane cannot drift from the other Dragon apps.
// A local debug build is re-id'd to <release-id>.debug and stamped DragonBuildChannel = Debug
// by tools/build-app.sh, so a test build still shows a distinct "Yahoo! KeyKey 2 Debug" name.
enum AboutConfig {
    // The channel the build script stamped, not the bundle id's ".debug" suffix this used to
    // sniff. Two derivations of one fact drift; the kit owns this one as of DragonKit 3.3.0.
    private static let isDebugBuild = DragonAbout.isDebugBuild()
    static let appName = "Yahoo! KeyKey 2" + (isDebugBuild ? " Debug" : "")

    // No " Debug" appended here any more: DragonAbout.versionString() renders the channel
    // itself from DragonBuildChannel — "v2.11.1 Debug (183) · 2026-Aug-09 17:31:39 UTC".
    // Appending it again would put a second "Debug" after the timestamp, at the line's end.
    static var versionString: String {
        DragonAbout.versionString()
    }

    @MainActor
    static var content: AboutContent {
        AboutContent(
            appName: appName,
            versionString: versionString,
            // Single holder, deliberately. The dual-holder form would also name the upstream
            // project's copyright, but this app is an independent reimplementation that uses no
            // Yahoo! KeyKey source code (docs/THIRD-PARTY-NOTICES.md) and disclaims affiliation
            // (README.md) — so claiming a Yahoo copyright over this binary would contradict both.
            // The lineage is carried by originalProjectURL and originalWork instead, and the New
            // BSD notice for the Yahoo-derived Cangjie tables lives on the licences page.
            copyright: DragonAbout.copyright(years: "2026", holder: "Teddy Chan"),
            // The canonical marketing page is repo-named; /keykey/ is a <meta refresh> stub whose
            // rel=canonical points here. The kit checks this path against supportURL's repo name.
            websiteURL: URL(string: "https://www.dragonapp.com/yahoo-keykey-2/")!,
            supportURL: URL(string: "https://github.com/teddychan/yahoo-keykey-2/issues")!,
            license: "MIT",
            originalProjectURL: URL(string: "https://github.com/ninjapanda/YahooKeyKey")!,
            // Third-party notices, chiefly OpenCC's Apache-2.0 licence and NOTICE, which that
            // licence requires ship with the app. Trailing slash: it is the path Pages serves, so
            // the row does not point at a redirect.
            licensesURL: URL(string: "https://www.dragonapp.com/yahoo-keykey-2/licenses/")!,
            originalWork: OriginalWork(name: "Yahoo! KeyKey", author: "ninjapanda · zonble"),
            // Attributions are name → licence, the kit's canon since 3.1.0: the thing's own name
            // as its authors spell it, then its licence. These were role labels paired with an
            // origin — L("keykey.about.cangjieTable") → "ibus-table-chinese" — on the reasoning
            // that an IME's data sources have no counterpart in the other apps, so they keep their
            // own localized keys. That reasoning was wrong on the canon's terms: a project name and
            // a licence identifier are proper nouns, not translatable prose. The three
            // keykey.about.* keys were deleted with the labels they fed.
            //
            // Every licence below is quoted from docs/THIRD-PARTY-NOTICES.md, never inferred — a
            // wrong licence here is an attribution error, not a cosmetic one. The Cangjie-5 table
            // has no SPDX identifier: its upstream header declares "LICENSE = Freely
            // redistributable without restriction", so it gets that phrase rather than an invented
            // id. It is specifically NOT GPL-3.0, which covers the surrounding ibus-table-chinese
            // repository packaging and not the one table this app bundles.
            attributions: [
                Attribution(name: "McBopomofo", license: "MIT"),
                Attribution(name: "ibus-table-chinese", license: "Freely redistributable without restriction"),
                Attribution(name: "OpenCC", license: "Apache-2.0"),
            ]
        )
    }
}
