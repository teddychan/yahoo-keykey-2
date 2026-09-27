import XCTest
@testable import KeyKeyApp

final class SystemInstallTests: XCTestCase {
    private static let home = "/Users/someone"
    private static let userCopy = "/Users/someone/Library/Input Methods/YahooKeyKey2.app"

    // MARK: location

    // macOS lets an input method work during secure input only when its bundle path starts with
    // exactly "/Library/Input Methods/" (HIToolbox compares the text, case and all), so that is the
    // one test for "already installed for all users".
    func testABundleUnderLibraryInputMethodsIsInstalledForAllUsers() {
        XCTAssertEqual(SystemInstall.location(ofBundleAt: "/Library/Input Methods/YahooKeyKey2.app",
                                              homeDirectory: Self.home, homebrewTargets: []),
                       .allUsers)
        XCTAssertEqual(SystemInstall.location(ofBundleAt: "/library/input methods/YahooKeyKey2.app",
                                              homeDirectory: Self.home, homebrewTargets: []),
                       .elsewhere)
    }

    func testTheUsersOwnInputMethodsFolderCanBeMovedFrom() {
        XCTAssertEqual(SystemInstall.location(ofBundleAt: Self.userCopy,
                                              homeDirectory: Self.home, homebrewTargets: []),
                       .currentUser)
        // The Debug build lives there too, under its own name, and moves to its own name.
        XCTAssertEqual(SystemInstall.location(
            ofBundleAt: "/Users/someone/Library/Input Methods/Yahoo KeyKey 2 Debug.app",
            homeDirectory: Self.home, homebrewTargets: []), .currentUser)
    }

    // Homebrew keeps a record of where it put the app. Moving that copy out from under it makes a
    // later `brew upgrade --cask` fail ("source is not there") and `brew uninstall` leave the moved
    // copy behind, so a cask-managed copy is Homebrew's to move.
    func testACopyHomebrewInstalledIsLeftToHomebrew() {
        XCTAssertEqual(SystemInstall.location(ofBundleAt: Self.userCopy, homeDirectory: Self.home,
                                              homebrewTargets: [Self.userCopy]),
                       .homebrew)
    }

    func testABuildFolderOrANestedCopyOffersNothing() {
        XCTAssertEqual(SystemInstall.location(
            ofBundleAt: "/Users/someone/git/yahoo-keykey-2/build/YahooKeyKey2.app",
            homeDirectory: Self.home, homebrewTargets: []), .elsewhere)
        XCTAssertEqual(SystemInstall.location(
            ofBundleAt: "/Users/someone/Library/Input Methods/old/YahooKeyKey2.app",
            homeDirectory: Self.home, homebrewTargets: []), .elsewhere)
    }

    // MARK: Homebrew's record

    func testHomebrewTargetsAreReadFromTheCaskroomSymlinks() throws {
        let caskroom = FileManager.default.temporaryDirectory
            .appendingPathComponent("SystemInstallTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: caskroom) }
        let versionDir = caskroom.appendingPathComponent("yahoo-keykey-2/2.15.0")
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
        // Homebrew links Caskroom/<token>/<version>/<app> to the installed target; the target need
        // not exist for the record to count.
        try FileManager.default.createSymbolicLink(
            atPath: versionDir.appendingPathComponent("YahooKeyKey2.app").path,
            withDestinationPath: Self.userCopy)

        XCTAssertEqual(SystemInstall.homebrewTargets(cask: "yahoo-keykey-2",
                                                     appName: "YahooKeyKey2.app",
                                                     caskrooms: [caskroom.path]),
                       [Self.userCopy])
        XCTAssertEqual(SystemInstall.homebrewTargets(cask: "yahoo-keykey-2",
                                                     appName: "YahooKeyKey2.app",
                                                     caskrooms: ["/nonexistent/Caskroom"]),
                       [])
    }

    // MARK: the password prompt

    // Every variable part reaches the root shell as an argv item through `quoted form of`; none is
    // spliced into AppleScript or shell source, so no path or translation can change what runs.
    func testOsascriptReceivesEveryValueAsAnArgumentNeverAsSource() {
        let hostile = "a\"b'c $(touch /tmp/pwned) `id` \\ 倉頡"
        let arguments = SystemInstall.osascriptArguments(
            source: "/Users/someone/Library/Input Methods/\(hostile).app",
            bundleName: "\(hostile).app", requirement: "=identifier \"\(hostile)\"",
            prompt: hostile)

        XCTAssertEqual(arguments.suffix(5), [
            SystemInstall.privilegedScript,
            "/Users/someone/Library/Input Methods/\(hostile).app",
            "\(hostile).app",
            "=identifier \"\(hostile)\"",
            hostile,
        ])
        let source = arguments.dropLast(5)
        XCTAssertEqual(source.enumerated().filter { $0.offset % 2 == 0 }.map(\.element),
                       ["-e", "-e", "-e"], "only -e scripts before the argv items")
        XCTAssertFalse(source.contains { $0.contains("pwned") || $0.contains("倉頡") })
        XCTAssertTrue(source.contains { $0.contains("with administrator privileges") })
    }

    // MARK: reading the result

    func testASuccessfulRunIsInstalled() {
        XCTAssertEqual(SystemInstall.outcome(exitStatus: 0, standardError: ""), .installed)
    }

    func testCancellingThePasswordPromptIsNotAnError() {
        XCTAssertEqual(SystemInstall.outcome(
            exitStatus: 1, standardError: "0:342: execution error: User canceled. (-128)\n"),
            .cancelled)
    }

    func testAFailureCarriesTheShellsOwnMessage() {
        XCTAssertEqual(SystemInstall.outcome(
            exitStatus: 1,
            standardError: "0:342: execution error: a sealed resource is missing or invalid (1)\n"),
            .failed("a sealed resource is missing or invalid"))
        XCTAssertEqual(SystemInstall.outcome(exitStatus: 1, standardError: "  something else \n"),
                       .failed("something else"))
    }

    // MARK: running it

    func testRunReturnsTheExitStatusAndWhatWasWrittenToStandardError() async {
        let result = await SystemInstall.run("/bin/sh", ["-c", "echo out; echo 'boom' >&2; exit 3"])
        XCTAssertEqual(result.status, 3)
        XCTAssertEqual(result.standardError, "boom\n")
    }

    func testAToolThatCannotLaunchIsAFailureNotAHang() async {
        let result = await SystemInstall.run("/nonexistent/osascript", [])
        XCTAssertEqual(result.status, -1)
        XCTAssertFalse(result.standardError.isEmpty)
        XCTAssertEqual(SystemInstall.outcome(exitStatus: result.status, standardError: result.standardError),
                       .failed(result.standardError))
    }

    // The requirement the root copy is checked against is read from THIS process's own signature,
    // and pins its exact code hash as well; `codesign -R` takes it as text only with the leading "=".
    func testTheRunningCodesOwnRequirementIsReadableAndPinsItsHash() throws {
        let requirement = try XCTUnwrap(SystemInstall.designatedRequirement())
        XCTAssertTrue(requirement.hasPrefix("=("))
        XCTAssertNotNil(requirement.range(of: #"\) and cdhash H"[0-9a-f]{40,64}"$"#, options: .regularExpression),
                        requirement)
    }

    // MARK: the privileged script

    func testThePrivilegedScriptParses() throws {
        XCTAssertEqual(try runScript(shellOptions: ["-n"], arguments: []), 0)
    }

    // The checks that run BEFORE the script touches the disk, exercised for real: a bundle name
    // that could leave /Library/Input Methods, and a source that is not a plain folder.
    func testThePrivilegedScriptRefusesANameThatLeavesTheFolder() throws {
        for name in ["../YahooKeyKey2.app", "a/b.app", ".hidden.app", "YahooKeyKey2", ""] {
            XCTAssertEqual(try runScript(arguments: ["/nonexistent", name, "=anything"]), 64, name)
        }
    }

    func testThePrivilegedScriptRefusesASourceThatIsNotAPlainFolder() throws {
        let link = FileManager.default.temporaryDirectory
            .appendingPathComponent("SystemInstallTests-link-\(UUID().uuidString).app")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/etc")
        defer { try? FileManager.default.removeItem(at: link) }

        XCTAssertEqual(try runScript(arguments: [link.path, "YahooKeyKey2.app", "=anything"]), 65)
        XCTAssertEqual(try runScript(arguments: ["/nonexistent", "YahooKeyKey2.app", "=anything"]), 65)
    }

    // The whole copy, run for real as the user against a scratch folder instead of
    // /Library/Input Methods — with the two steps that need root or a real signature (chown,
    // codesign) taken out. What it pins: an ACL the user put on the source does not survive into the
    // installed copy (ditto copies ACLs, and one would keep a root-owned copy writable), nothing
    // ends up group- or world-writable, an older copy is replaced, and no staging folder is left.
    func testThePrivilegedCopyStripsACLsAndReplacesAnOlderCopy() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("SystemInstallTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }
        let binary = root.appendingPathComponent("src/Fake.app/Contents/MacOS/Fake")
        try fileManager.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("new".utf8).write(to: binary)
        XCTAssertEqual(try run("/bin/chmod", ["+a", "everyone allow write,delete", binary.path]), 0)
        XCTAssertEqual(try run("/bin/chmod", ["g+w,o+w", binary.path]), 0)
        let destination = root.appendingPathComponent("dest")
        let older = destination.appendingPathComponent("Fake.app/Contents/MacOS/Fake")
        try fileManager.createDirectory(at: older.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: older)

        var script = SystemInstall.privilegedScript
        for (line, replacement) in [
            ("dir='/Library/Input Methods'", "dir='\(destination.path)'"),
            (#"/usr/sbin/chown -R root:wheel "$stage/new.app""#, ":"),
            (#"/usr/bin/codesign --verify --deep --strict -R "$requirement" "$stage/new.app""#, ":"),
        ] {
            XCTAssertNotNil(script.range(of: line), "the script no longer contains: \(line)")
            script = script.replacingOccurrences(of: line, with: replacement)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "keykey-install",
                             root.appendingPathComponent("src/Fake.app").path, "Fake.app", "=unused"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        XCTAssertEqual(try String(contentsOf: older, encoding: .utf8), "new", "the older copy was replaced")
        let listing = try output("/bin/ls", ["-leR", destination.appendingPathComponent("Fake.app").path])
        XCTAssertFalse(listing.contains("allow"), "an ACL survived:\n\(listing)")
        let mode = try XCTUnwrap(fileManager.attributesOfItem(atPath: older.path)[.posixPermissions] as? Int)
        XCTAssertEqual(mode & 0o022, 0, "group/other write survived")
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: destination.path), ["Fake.app"],
                       "a staging folder was left behind")
    }

    private func run(_ executable: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private func output(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private func runScript(shellOptions: [String] = [], arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = shellOptions + ["-c", SystemInstall.privilegedScript, "keykey-install"]
            + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
