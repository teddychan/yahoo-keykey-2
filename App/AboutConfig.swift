import Foundation
import DragonKit

// About-pane content, ported from the old AboutWindow.swift. Reuses the same name, links,
// and origin/data attributions. Debug builds re-id the bundle to <release-id>.debug; detect
// that so a test build shows a distinct "Yahoo! KeyKey 2 Debug" name/version like before.
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
            copyright: "倉頡／簡易 輸入法",
            links: [
                AboutLink(
                    title: L("keykey.about.website"),
                    detail: "www.dragonapp.com/keykey",
                    systemImage: "globe",
                    url: URL(string: "https://www.dragonapp.com/keykey")!
                ),
                AboutLink(
                    title: L("keykey.about.support"),
                    detail: "teddychan/yahoo-keykey-2",
                    systemImage: "ladybug",
                    url: URL(string: "https://github.com/teddychan/yahoo-keykey-2/issues")!
                ),
                AboutLink(
                    title: L("keykey.about.origin"),
                    detail: "ninjapanda/YahooKeyKey",
                    systemImage: "heart",
                    url: URL(string: "https://github.com/ninjapanda/YahooKeyKey")!
                ),
            ],
            credits: [
                (label: L("keykey.about.origin"), value: "Yahoo! KeyKey (ninjapanda · zonble)"),
                (label: L("keykey.about.languageModel"), value: "openvanilla/McBopomofo"),
                (label: L("keykey.about.cangjieTable"), value: "ibus-table-chinese"),
                (label: L("keykey.about.hanConversion"), value: "OpenCC (Apache-2.0)"),
            ]
        )
    }
}
