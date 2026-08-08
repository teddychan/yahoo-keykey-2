import Foundation
import DragonKit

// About-pane content. DragonKit v3 owns every row title, SF Symbol and ordering — this file
// supplies only URLs and proper nouns, so the pane cannot drift from the other Dragon apps.
// Debug builds re-id the bundle to <release-id>.debug; detect that so a test build shows a
// distinct "Yahoo! KeyKey 2 Debug" name/version like before.
enum AboutConfig {
    private static let isDebugBuild = Bundle.main.bundleIdentifier?.hasSuffix(".debug") ?? false
    static let appName = "Yahoo! KeyKey 2" + (isDebugBuild ? " Debug" : "")

    static var versionString: String {
        return DragonAbout.versionString() + (isDebugBuild ? " Debug" : "")
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
            // The only app-specific rows in the pane. Unlike the canon labels above the kit does
            // not own these — an IME's data sources have no counterpart in the other apps — so
            // they keep their own localized keys.
            attributions: [
                Attribution(component: L("keykey.about.languageModel"), source: "openvanilla/McBopomofo"),
                Attribution(component: L("keykey.about.cangjieTable"), source: "ibus-table-chinese"),
                Attribution(component: L("keykey.about.hanConversion"), source: "OpenCC (Apache-2.0)"),
            ]
        )
    }
}
