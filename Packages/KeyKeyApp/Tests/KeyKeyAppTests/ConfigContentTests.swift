import XCTest
import DragonKit
@testable import KeyKeyApp

// Covers the About-pane and What's-New content builders. These assemble DragonKit content
// structs from static data; the tests assert the structure (names, links, credits, version,
// change sections) rather than localized strings, which vary with the runtime bundle.
final class ConfigContentTests: XCTestCase {

    // MARK: AboutConfig

    @MainActor
    func testAboutAppNameIsReleaseNameOutsideDebugBuild() {
        // The test bundle id does not end in ".debug", so no " Debug" suffix is appended.
        XCTAssertEqual(AboutConfig.appName, "Yahoo! KeyKey 2")
    }

    @MainActor
    func testAboutVersionStringIsFormatted() {
        XCTAssertTrue(AboutConfig.versionString.hasPrefix("v"))
    }

    @MainActor
    func testAboutContentStructure() {
        let content = AboutConfig.content
        XCTAssertEqual(content.appName, "Yahoo! KeyKey 2")
        // A real copyright, not the IME description that used to sit in this slot.
        XCTAssertEqual(content.copyright, "© 2026 Teddy Chan")
        XCTAssertEqual(content.license, "MIT")
        // Both optional link slots are filled, so all four canon rows render, in kit order. The
        // titles and symbols are the kit's; what this pins is that the app fills the right slots.
        XCTAssertEqual(content.linkRows.map(\.systemImage),
                       ["globe", "lifepreserver", "heart", "doc.text"])
        // Details are derived from the URLs, so asserting them pins where each row actually goes.
        XCTAssertEqual(content.linkRows.map(\.detail), [
            "dragonapp.com/yahoo-keykey-2",
            "teddychan/yahoo-keykey-2",
            "ninjapanda/YahooKeyKey",
            "dragonapp.com/yahoo-keykey-2/licenses",
        ])
        for row in content.linkRows {
            XCTAssertEqual(row.url.scheme, "https")
        }
    }

    // The Website row must address this repo's canonical page. It pointed at
    // www.dragonapp.com/keykey, a <meta refresh> stub whose canonical is /yahoo-keykey-2/.
    @MainActor
    func testAboutWebsiteMatchesSupportRepo() {
        XCTAssertTrue(AboutConfig.content.websiteMatchesSupportRepo)
    }

    // Created by → Based on → Built with → License, then the app's own data attributions last.
    // "Homage to the original" used to appear twice, as both a link and a credit; it is now the
    // Original project link plus this one Based-on credit.
    @MainActor
    func testAboutCreditRowsEndWithTheDataAttributions() {
        let content = AboutConfig.content
        XCTAssertEqual(content.originalWork,
                       OriginalWork(name: "Yahoo! KeyKey", author: "ninjapanda · zonble"))
        XCTAssertEqual(content.creditRows.count, 7)
        // Pinned as name → licence pairs, not values alone. The kit renders an Attribution as
        // label: name, value: licence, so checking one half would let a role label ("Cangjie
        // table") or a wrong licence back in — and these rows were role labels until 3.1.0.
        // Licences track docs/THIRD-PARTY-NOTICES.md; the Cangjie table has no SPDX id.
        XCTAssertEqual(content.creditRows.suffix(3).map { [$0.label, $0.value] },
                       [["McBopomofo", "MIT"],
                        ["ibus-table-chinese", "Freely redistributable without restriction"],
                        ["OpenCC", "Apache-2.0"]])
    }

    // MARK: WhatsNewConfig

    // The pane hardcoded "2.10.0" while About read the bundle, so the two would disagree the day
    // 2.11.0 shipped. It now takes no version argument and reads CFBundleShortVersionString —
    // re-adding a literal fails here, because the expectation is computed from the same bundle.
    @MainActor
    func testWhatsNewVersionTracksTheBundleAndIsPrefixed() {
        let content = WhatsNewConfig.content
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        XCTAssertEqual(content.displayVersion, DragonVersion.display(short ?? "1.0.0"))
        XCTAssertTrue(content.displayVersion.hasPrefix("v"))
        XCTAssertEqual(content.date, "2026-08-07")
    }

    @MainActor
    func testWhatsNewSectionsAreAddedImprovedFixedInOrder() {
        let content = WhatsNewConfig.content
        XCTAssertEqual(content.sections.map(\.kind), [.added, .improved, .fixed])
        XCTAssertEqual(content.sections.map(\.entries.count), [1, 2, 4])
    }

    // MARK: DragonAppMenu contract

    // Pins the shape App/InputController.swift depends on. The input menu sources its app
    // items from DragonAppMenu and then re-points each one at a real @objc selector, matching
    // by title, because IMK routes a top-level selection back to the controller and ignores
    // the item's own target. That lookup is only total while the kit returns exactly these
    // three titles — so assert the contract here, where a kit change fails CI, rather than
    // trusting it at runtime inside an input method (which must not trap).
    //
    // Titles are compared against the same L() keys the kit formats them from, so this holds
    // in whatever language the test bundle resolves — it pins the item set and its order, not
    // the localized wording.
    @MainActor
    func testDragonAppMenuReturnsTheThreeItemsTheInputMenuWiresUp() {
        let appName = "Yahoo! KeyKey 2"
        let items = DragonAppMenu.items(
            DragonAppMenu.Config(
                appName: appName,
                onAbout: {},
                onSettings: {},
                onCheckForUpdates: {},
                includeQuit: false
            )
        )
        XCTAssertEqual(items.map(\.title), [
            String(format: L("DragonKit.menu.about"), appName),
            L("DragonKit.menu.checkForUpdates"),
            L("DragonKit.menu.settings"),
        ])
        // No separators to skip, and every item carries its canonical leading SF Symbol.
        XCTAssertFalse(items.contains(where: \.isSeparatorItem))
        XCTAssertTrue(items.allSatisfy { $0.image != nil })
    }
}
