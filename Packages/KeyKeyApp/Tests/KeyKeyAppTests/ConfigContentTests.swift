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
        // The test bundle carries no DragonBuildChannel, so DragonAbout.isDebugBuild() is
        // false and no " Debug" suffix is appended. (It used to sniff the bundle id's ".debug"
        // suffix; the channel the build script stamps is the kit-owned signal since 3.3.0.)
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
        // The url is part of OriginalWork as of DragonKit 4.0.0, and it is the same value the
        // `heart` link row above renders — one value feeding both rows is the point of folding it
        // in, so asserting it here pins the credit and the link together.
        XCTAssertEqual(content.originalWork,
                       OriginalWork(name: "Yahoo! KeyKey",
                                    author: "ninjapanda · zonble",
                                    url: URL(string: "https://github.com/ninjapanda/YahooKeyKey")!))
        XCTAssertEqual(content.originalProjectURL, content.originalWork?.url)
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
        XCTAssertEqual(content.date, "2026-08-20")
    }

    // 2.13.3 is [.fixed, .changed], and unlike 2.13.2 it is NOT maintenance-only: the DragonKit pin
    // moved v4.1.0 -> v4.1.1 and brought a real behaviour change with it. Uninstall now refuses to
    // run when a second copy of the app is on the Mac, because settings, the login item, support
    // files and the Homebrew record are all keyed to the app's identity rather than its location,
    // so uninstalling a spare copy could destroy the real copy's data.
    //
    // `.fixed` even though no App/ source changed: what a user MEETS is different, which is the
    // test 2.13.2 failed and correctly reported as `.changed`. `.fixed` leads, so the version
    // number never sits above the safety fix it delivered.
    //
    // 4.1.1's other fix is deliberately unasserted because it is deliberately unannounced — it
    // silenced a raw developer error reachable only from a local Debug build, so no shipped copy
    // could hit it. It lives in CHANGELOG.md.
    //
    // Entry KEYS are pinned, not just kinds and counts, because kinds and counts had stopped
    // catching anything: 2.11.3, 2.11.4 and the 2.11.5 draft were all [.changed] with one entry —
    // three in a row — so a release that forgot to touch the notes would have passed unchanged
    // while shipping its predecessor's text. Compared against the same L() keys WhatsNewConfig
    // builds the entries from, so this holds in whatever language the test bundle resolves,
    // exactly as the DragonAppMenu test below compares titles against the kit's keys. What the
    // text SAYS is the release gate's job — it diffs every locale's .strings file — so between
    // them a stale pane cannot ship.
    @MainActor
    func testWhatsNewAnnouncesTheUninstallFixAndTheKitBump() {
        let content = WhatsNewConfig.content
        XCTAssertEqual(content.sections.map(\.kind), [.fixed, .changed])
        XCTAssertEqual(content.sections.map(\.entries.count), [1, 1])
        XCTAssertEqual(content.sections.flatMap(\.entries), [
            L("app.whatsNew.fixed1"),
            L("app.whatsNew.changed1"),
        ])
    }

    // MARK: LanguagePicker configuration

    // The picker must offer exactly the languages KeyKey has translated ITSELF into, and nothing
    // observable tied those two facts together until this test. That is how 2.11.4 shipped a menu
    // offering Español, Français, 日本語, 한국어 and 简体中文 with no KeyKey strings behind them:
    // App/GeneralPane.swift called LanguagePicker() bare and took the kit's default of
    // DragonLanguage.selectable, all seven locales DragonKit ships.
    //
    // It cannot be asserted through the type. LanguagePicker keeps `languages` private and
    // `offeredLanguages` internal, so a constructed picker reveals nothing to an app-side test —
    // and App/GeneralPane.swift is not one of the files symlinked into this package, so the call
    // site is not reachable as code either. What is reachable is the pair of artifacts that must
    // agree: the argument written at the call site, and the .lproj directories that exist. Reading
    // those from disk is how the sibling engine suites reach Resources/, and comparing source text
    // against the repo is what Scripts/dragon-conformance.py does with these same files.
    //
    // A bare call is not itself the bug, and asserting that an explicit `languages:` exists was
    // the wrong shape of test: as of 2.12.0 KeyKey ships all seven .lproj, so the kit's default IS
    // the correct list and App/GeneralPane.swift is bare again. What matters is only whether the
    // two sets agree, so this resolves a bare call to DragonLanguage.selectable and compares that,
    // exactly as DragonKit CONFORMANCE §R13 now does for all five Dragon apps.
    //
    // Fails in every direction that matters: dropping a locale without narrowing the picker,
    // narrowing the picker while the .lproj is still shipped, a hand-written list that disagrees
    // with disk, and deleting the picker altogether. The one thing it can no longer fail on is the
    // shape of the call — which is right, because both shapes are correct for some app.
    @MainActor
    func testLanguagePickerOffersExactlyTheShippedLocalizations() throws {
        var dir = URL(fileURLWithPath: #filePath)
        var found: URL?
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("App/GeneralPane.swift").path) {
                found = dir.appendingPathComponent("App")
                break
            }
        }
        guard let appDir = found else { throw XCTSkip("App/GeneralPane.swift not present above this package") }

        // Comment lines go first, so prose naming the call cannot satisfy the search below.
        let code = try String(contentsOf: appDir.appendingPathComponent("GeneralPane.swift"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        // Deleting the picker would otherwise leave nothing to compare, and a comparison with no
        // subject passes.
        guard code.range(of: "LanguagePicker(") != nil else {
            return XCTFail("App/GeneralPane.swift no longer constructs a LanguagePicker")
        }

        let offered: Set<String>
        if let call = code.range(of: "LanguagePicker(languages:"),
           let open = code.range(of: "[", range: call.upperBound..<code.endIndex),
           let close = code.range(of: "]", range: open.upperBound..<code.endIndex) {
            let tokens = code[open.upperBound..<close.lowerBound]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
                .filter { !$0.isEmpty }
            // Case names in source ("zhHant") to locale codes ("zh-Hant"), which is what an .lproj
            // is named. Asserting the count survives the mapping stops an unrecognized token from
            // being dropped and letting both sides agree by being equally short.
            offered = Set(tokens.compactMap { token in
                DragonLanguage.allCases.first { String(describing: $0) == token }?.rawValue
            })
            XCTAssertEqual(offered.count, tokens.count,
                           "a language in the picker's list matches no DragonLanguage case: \(tokens)")
        } else {
            // No argument means the kit's default. Read from DragonLanguage rather than written out
            // as seven codes, so the day the kit adds an eighth this fails against App/*.lproj
            // instead of comparing against a list that stopped describing the picker.
            offered = Set(DragonLanguage.selectable.map(\.rawValue))
        }

        XCTAssertEqual(offered, shippedLocalizations(in: appDir),
                       "the Language picker and App/*.lproj disagree")
    }

    // Every locale must define the same keys. A key present in en.lproj and missing from ko.lproj
    // falls back to English silently — no crash, no warning, just one English row in an otherwise
    // Korean pane — and going from two locales to seven multiplies the places that can happen.
    // DragonKit pins its own seven the same way (LocalizationTests.allLanguagesDefineTheSameKeys);
    // nothing pinned KeyKey's until now, which was survivable at two files and is not at seven.
    func testEveryLocalizationDefinesTheSameKeys() throws {
        var dir = URL(fileURLWithPath: #filePath)
        var found: URL?
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("App/GeneralPane.swift").path) {
                found = dir.appendingPathComponent("App")
                break
            }
        }
        guard let appDir = found else { throw XCTSkip("App/ not present above this package") }

        let locales = shippedLocalizations(in: appDir).sorted()
        XCTAssertTrue(locales.contains("en"), "no en.lproj to compare the others against")

        func keys(_ locale: String) throws -> Set<String> {
            let url = appDir.appendingPathComponent("\(locale).lproj/Localizable.strings")
            let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String],
                                      "\(locale).lproj/Localizable.strings is missing or malformed")
            // An empty value resolves to "" and renders as a blank row, which reads as a layout bug
            // rather than a missing translation, so it is caught here and not left to a screenshot.
            XCTAssertEqual(table.filter { $0.value.isEmpty }.map(\.key), [],
                           "\(locale) has empty values")
            return Set(table.keys)
        }

        let english = try keys("en")
        XCTAssertFalse(english.isEmpty)
        for locale in locales where locale != "en" {
            XCTAssertEqual(try keys(locale), english, "\(locale) key set differs from en")
        }
    }

    /// The locale codes KeyKey ships its own strings in, read from the `.lproj` directories.
    private func shippedLocalizations(in appDir: URL) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: appDir.path)) ?? []
        return Set(names.filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(".lproj".count)) })
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
