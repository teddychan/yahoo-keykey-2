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
        XCTAssertEqual(content.version, "2.6.4")
        XCTAssertEqual(content.date, "2026-07-10")
    }

    @MainActor
    func testWhatsNewHasSingleChangedSectionWithTwoEntries() {
        let content = WhatsNewConfig.content
        XCTAssertEqual(content.sections.count, 1)
        let section = content.sections[0]
        XCTAssertEqual(section.kind, .changed)
        XCTAssertEqual(section.entries.count, 2)
    }
}
