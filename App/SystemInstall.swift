import AppKit
import Carbon
import Security

// Installing the running input method for every account on the Mac, in /Library/Input Methods.
//
// Why it exists (issue #134, known_issues.md #2): while any app holds macOS secure input —
// 1Password 8.12.36 routinely leaks it across a screen lock — HIToolbox lets through only Apple's
// own sources, keyboard layouts, and input methods whose bundle path starts with
// "/Library/Input Methods/". Everything else is greyed out in the input menu AND refused
// keystrokes. Every channel used to install KeyKey into ~/Library/Input Methods, which can never
// qualify; Google Japanese Input and Squirrel stay usable during the same lock for this reason
// alone. The rule is undocumented — read from HIToolbox (_islGetInputSourceIsSecureCandidate) on
// macOS 27.0 and confirmed by moving a copy there — so a future macOS could change it.
//
// The move needs root, because /Library/Input Methods is root:wheel 755. KeyKey asks once, through
// osascript's `do shell script … with administrator privileges`: the one-shot route Apple DTS
// points to, and one that needs no entitlement, since KeyKey sends Apple events to no other app.
// The copy it installs is root:wheel on purpose. A bundle the user could write to would let
// user-level code tamper with an input method macOS trusts during secure input, and would hand root
// to whatever replaced Sparkle's Autoupdate inside it at the next authorized update. Sparkle keeps
// the installed copy's owner on every later update, and asks for an administrator password each
// time, because the folder is not writable.
enum SystemInstall {
    /// The folder macOS trusts during secure input. HIToolbox compares this prefix as text, case and
    /// all, so it is compared the same way here.
    static let directory = "/Library/Input Methods"

    /// The Homebrew cask that installs KeyKey — the token `Casks/yahoo-keykey-2.rb` in
    /// teddychan/homebrew-tap declares.
    static let homebrewCask = "yahoo-keykey-2"

    enum Location: Equatable {
        /// Under /Library/Input Methods already: nothing to do.
        case allUsers
        /// Directly in the user's own ~/Library/Input Methods, put there by hand: KeyKey can move it.
        case currentUser
        /// Homebrew's cask target. `brew reinstall --cask yahoo-keykey-2` moves it; KeyKey must not,
        /// or brew's record points at nothing — `brew upgrade` then fails with "source is not
        /// there" and `brew uninstall` leaves the moved copy behind.
        case homebrew
        /// A build folder, a nested or translocated copy: offer nothing.
        case elsewhere
    }

    /// Where the bundle at `path` is installed, from the path alone.
    static func location(ofBundleAt path: String, homeDirectory: String,
                         homebrewTargets: Set<String>) -> Location {
        if path.hasPrefix(directory + "/") { return .allUsers }
        let userDirectory = (homeDirectory as NSString).appendingPathComponent("Library/Input Methods")
        guard (path as NSString).deletingLastPathComponent == userDirectory else { return .elsewhere }
        return homebrewTargets.contains(path) ? .homebrew : .currentUser
    }

    /// The paths Homebrew installed `appName` to for `cask`, read from the symlinks it keeps at
    /// `<caskroom>/<cask>/<version>/<app>`. Empty when Homebrew or the cask is absent, which is
    /// the ordinary case rather than an error.
    static func homebrewTargets(cask: String, appName: String,
                                caskrooms: [String] = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"])
        -> Set<String> {
        let fileManager = FileManager.default
        var targets: Set<String> = []
        for caskroom in caskrooms {
            let caskDirectory = (caskroom as NSString).appendingPathComponent(cask)
            guard let versions = try? fileManager.contentsOfDirectory(atPath: caskDirectory) else { continue }
            for version in versions {
                let versionDirectory = (caskDirectory as NSString).appendingPathComponent(version)
                let link = (versionDirectory as NSString).appendingPathComponent(appName)
                guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: link) else { continue }
                let absolute = destination.hasPrefix("/")
                    ? destination : (versionDirectory as NSString).appendingPathComponent(destination)
                targets.insert((absolute as NSString).standardizingPath)
            }
        }
        return targets
    }

    // MARK: - The privileged copy

    /// Runs as root with `$1` the running bundle, `$2` its file name, `$3` the `codesign -R`
    /// requirement it must still satisfy.
    ///
    /// Nothing from the user-writable source is executed, and nothing under the user's home folder
    /// is written: the copy is made into a root-only staging folder, made root:wheel and
    /// non-writable — ACLs stripped too (`chmod -N`), because ditto copies them and an ACL the user
    /// planted on the source would otherwise keep the root-owned copy writable — and only THEN
    /// checked against the signature the running process has, so the bytes checked are bytes
    /// user-level code can no longer change. Nothing follows a symlink as root (ditto, chown -R,
    /// chmod -R and `xattr -s` all act on the link itself). An older copy already in place is
    /// swapped out last, and put back if anything before that fails.
    static let privilegedScript = """
        set -eu
        src=$1
        name=$2
        requirement=$3
        dir='/Library/Input Methods'
        case $name in
          ''|.*|*/*) exit 64 ;;
          *.app) ;;
          *) exit 64 ;;
        esac
        if [ -L "$src" ] || [ ! -d "$src" ]; then exit 65; fi
        dst=$dir/$name
        /bin/mkdir -p "$dir"
        stage=$(/usr/bin/mktemp -d "$dir/.keykey-install.XXXXXX")
        restore() {
          if [ ! -e "$dst" ] && [ -e "$stage/previous.app" ]; then /bin/mv "$stage/previous.app" "$dst"; fi
          /bin/rm -rf "$stage"
        }
        trap restore EXIT
        /usr/bin/ditto "$src" "$stage/new.app"
        /usr/sbin/chown -R root:wheel "$stage/new.app"
        /bin/chmod -R -N "$stage/new.app"
        /bin/chmod -R a+rX,go-w "$stage/new.app"
        /usr/bin/xattr -drs com.apple.quarantine "$stage/new.app"
        /usr/bin/codesign --verify --deep --strict -R "$requirement" "$stage/new.app"
        if [ -e "$dst" ]; then /bin/mv "$dst" "$stage/previous.app"; fi
        /bin/mv "$stage/new.app" "$dst"
        """

    /// The `/usr/bin/osascript` arguments that run ``privilegedScript`` as root once an
    /// administrator has answered the password prompt.
    ///
    /// Every variable part — paths, requirement, the localized prompt — travels as an argv item and
    /// reaches the shell through `quoted form of`. None is spliced into AppleScript or shell
    /// source, so no bundle path or translation can change what runs as root.
    static func osascriptArguments(source: String, bundleName: String, requirement: String,
                                   prompt: String) -> [String] {
        [
            "-e", "on run argv",
            "-e", "do shell script \"/bin/sh -c \" & quoted form of (item 1 of argv)"
                + " & \" keykey-install \" & quoted form of (item 2 of argv)"
                + " & \" \" & quoted form of (item 3 of argv)"
                + " & \" \" & quoted form of (item 4 of argv)"
                + " with prompt (item 5 of argv) with administrator privileges",
            "-e", "end run",
            privilegedScript, source, bundleName, requirement, prompt,
        ]
    }

    enum Outcome: Equatable {
        case installed
        /// The password prompt was dismissed. Not an error: nothing was changed.
        case cancelled
        /// The shell's own message, e.g. codesign's, with osascript's framing removed.
        case failed(String)
        /// This copy's own signature could not be established, so nothing was attempted.
        case signatureUnreadable
    }

    /// Reads osascript's exit status and standard error. A failed `do shell script` is reported as
    /// "<start>:<end>: execution error: <the command's stderr> (<its exit status>)", and cancelling
    /// the prompt as "… User canceled. (-128)".
    static func outcome(exitStatus: Int32, standardError: String) -> Outcome {
        if exitStatus == 0 { return .installed }
        let text = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("(-128)") { return .cancelled }
        var message = text
        if let marker = message.range(of: "execution error: ") {
            message = String(message[marker.upperBound...])
        }
        if message.hasSuffix(")"), let open = message.range(of: " (", options: .backwards),
           Int(message[open.upperBound..<message.index(before: message.endIndex)]) != nil {
            message = String(message[..<open.lowerBound])
        }
        return .failed(message)
    }

    /// The requirement the root copy must satisfy, as `codesign -R` text: the running code's
    /// designated requirement (Developer ID and team for a release; a code hash for the ad-hoc Debug
    /// build) AND its exact code hash, so neither a different build nor an older genuine release
    /// swapped in at the same path can be installed. nil when it cannot be established — and then
    /// nothing is installed, because the root copy would go unchecked.
    ///
    /// The requirement is read from the bundle on disk, so the running code is first checked
    /// against that bundle: `SecCodeCheckValidity` fails if the file was replaced after launch.
    static func designatedRequirement() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCheckValidity(code, [], nil) == errSecSuccess else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess,
              let requirement else { return nil }
        var text: CFString?
        guard SecRequirementCopyString(requirement, [], &text) == errSecSuccess, let text else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, [], &information) == errSecSuccess,
              let unique = (information as? [String: Any])?[kSecCodeInfoUnique as String] as? Data
        else { return nil }
        let hash = unique.map { String(format: "%02x", $0) }.joined()
        return "=(" + (text as String) + ") and cdhash H\"" + hash + "\""
    }

    /// Asks for an administrator password and installs a root-owned copy of `bundle` at
    /// /Library/Input Methods/<its name>. Suspends until the prompt is answered and the copy is
    /// finished; the running copy is left where it is.
    static func installCopy(of bundle: URL, prompt: String) async -> Outcome {
        guard let requirement = designatedRequirement() else { return .signatureUnreadable }
        let arguments = osascriptArguments(source: bundle.path, bundleName: bundle.lastPathComponent,
                                           requirement: requirement, prompt: prompt)
        let result = await run("/usr/bin/osascript", arguments)
        return outcome(exitStatus: result.status, standardError: result.standardError)
    }

    /// Runs `executable` to completion and returns its exit status and standard error. A launch
    /// failure reports as status -1 with the launch error's description, so it surfaces as a failure
    /// rather than a hang.
    static func run(_ executable: String, _ arguments: [String]) async
        -> (status: Int32, standardError: String) {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            let errors = Pipe()
            process.standardError = errors
            let reader = errors.fileHandleForReading
            process.terminationHandler = { finished in
                let text = String(decoding: reader.readDataToEndOfFile(), as: UTF8.self)
                continuation.resume(returning: (finished.terminationStatus, text))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: (-1, error.localizedDescription))
            }
        }
    }

    /// Hands over to the copy in /Library/Input Methods: tells TIS where the input method now lives,
    /// then quits. macOS relaunches it from there on the next keystroke — the enabled input sources
    /// are keyed by bundle and mode id, not path, so they carry over — the same quit-and-relaunch
    /// the Backup pane's restore relies on.
    @MainActor
    static func relaunch(from newCopy: URL) {
        let status = TISRegisterInputSource(newCopy as CFURL)
        if status != noErr { NSLog("YahooKeyKey: TISRegisterInputSource(%@) returned %d", newCopy.path, status) }
        NSApp.terminate(nil)
    }
}
