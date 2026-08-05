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
        XCTAssertEqual(content.copyright, "倉頡／簡易 輸入法")
        XCTAssertEqual(content.links.count, 3)
        XCTAssertEqual(content.credits.count, 4)
        // Every link carries a resolvable https URL and an SF Symbol name.
        for link in content.links {
            XCTAssertEqual(link.url.scheme, "https")
            XCTAssertFalse(link.systemImage.isEmpty)
        }
        XCTAssertEqual(content.links.map(\.detail),
                       ["www.dragonapp.com/keykey", "teddychan/yahoo-keykey-2", "ninjapanda/YahooKeyKey"])
    }

    // MARK: WhatsNewConfig

    @MainActor
    func testWhatsNewVersionMatchesCurrentRelease() {
        let content = WhatsNewConfig.content
        XCTAssertEqual(content.version, "2.9.0")
        XCTAssertEqual(content.date, "2026-08-05")
    }

    @MainActor
    func testWhatsNewHasChangedSection() {
        let content = WhatsNewConfig.content
        XCTAssertEqual(content.sections.count, 1)
        XCTAssertEqual(content.sections[0].kind, .changed)
        XCTAssertEqual(content.sections[0].entries.count, 2)
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
