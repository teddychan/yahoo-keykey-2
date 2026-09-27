import SwiftUI
import DragonKit
import KeyKeyEngine

// KeyKey's General settings pane: the 安裝 section first (it moves this copy to /Library/Input
// Methods — see SystemInstall), then the real input toggles (輸出簡體字 / 全形標點 / 聯想字詞 and the
// 聯想只顯示接續字 option), the candidate font size, the 倉頡版本 picker and 以空白鍵確認字根
// toggle, and the shared language picker. Everything but the 安裝 section binds to `SettingsModel`,
// which forwards to the live `Preferences` the engine reads — so changes apply on the next
// composition, no restart.
struct GeneralPane: SettingsPane {
    let id = "general"
    let title = "keykey.pane.general"
    let systemImage = "gearshape"
    let model: SettingsModel

    var paneBody: some View { GeneralPaneView(model: model) }
}

private struct GeneralPaneView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        DragonForm {
            // First, because it decides whether everything below keeps working while another app
            // holds secure input. Hidden for a copy running from anywhere else (a build folder, a
            // translocated copy), which has no install to speak of.
            if installation.location != .elsewhere {
                DragonSection(LocalizedStringKey(L("keykey.general.installation"))) {
                    InstallationRow(model: installation)
                }
            }

            DragonSection(LocalizedStringKey(L("keykey.general.input"))) {
                Toggle(L("keykey.general.outputSimplified"), isOn: $model.outputSimplified)
                Toggle(L("keykey.general.fullWidthPunctuation"), isOn: $model.fullWidthPunctuation)
                Toggle(L("keykey.general.shiftSpaceFullWidthSpace"), isOn: $model.shiftSpaceFullWidthSpace)
                    .dragonAnnotation(LocalizedStringKey(L("keykey.general.shiftSpaceFullWidthSpaceHint")))
                Toggle(L("keykey.general.associatedPhrases"), isOn: $model.associatedPhrases)
                Toggle(L("keykey.general.associationContinuationOnly"), isOn: $model.associationContinuationOnly)
                    .dragonAnnotation(LocalizedStringKey(L("keykey.general.associationContinuationOnlyHint")))
                Picker(L("keykey.general.associationTrigger"), selection: $model.associationTrigger) {
                    Text(L("keykey.general.associationTriggerNumber")).tag(AssociationTrigger.number)
                    Text(L("keykey.general.associationTriggerShift")).tag(AssociationTrigger.shift)
                }
                .dragonAnnotation(LocalizedStringKey(L("keykey.general.associationTriggerHint")))
                Toggle(L("keykey.general.codeHint"), isOn: $model.codeHint)
                    .dragonAnnotation(LocalizedStringKey(L("keykey.general.codeHintHint")))
            }

            DragonSection(LocalizedStringKey(L("keykey.general.appearance"))) {
                Slider(
                    value: $model.candidateFontSize,
                    in: model.minFontSize...model.maxFontSize,
                    step: 1
                ) {
                    Text(L("keykey.general.candidateFontSize"))
                } minimumValueLabel: {
                    Text("A").font(.system(size: 11))
                } maximumValueLabel: {
                    Text("A").font(.system(size: 17))
                }
                .dragonAnnotation(LocalizedStringKey("\(Int(model.candidateFontSize)) pt"))
            }

            DragonSection(LocalizedStringKey(L("keykey.general.inputMethod"))) {
                Picker(L("keykey.general.cangjieVersion"), selection: $model.cangjieVersion) {
                    Text(L("keykey.general.cangjieV5")).tag(CangjieVersion.v5)
                    Text(L("keykey.general.cangjieV3")).tag(CangjieVersion.v3)
                }
                .dragonAnnotation(LocalizedStringKey(L("keykey.general.cangjieVersionHint")))
                Picker(L("keykey.general.zhuyinLayout"), selection: $model.zhuyinLayout) {
                    Text(L("keykey.general.zhuyinLayoutDachen")).tag(ZhuyinLayout.dachen)
                    Text(L("keykey.general.zhuyinLayoutEten")).tag(ZhuyinLayout.eten)
                }
                .dragonAnnotation(LocalizedStringKey(L("keykey.general.zhuyinLayoutHint")))
                Toggle(L("keykey.general.strokeConfirmation"), isOn: $model.strokeConfirmation)
                    .dragonAnnotation(LocalizedStringKey(L("keykey.general.strokeConfirmationHint")))
                // Governs every input method, not just the 倉頡版本 above it — hence the explicit
                // 倉頡/速成/注音 list in the hint rather than a position that implies otherwise.
                Toggle(L("keykey.general.adaptiveCandidateOrder"), isOn: $model.adaptiveCandidateOrder)
                    .dragonAnnotation(LocalizedStringKey(L("keykey.general.adaptiveCandidateOrderHint")))
            }

            DragonSection(LocalizedStringKey(L("keykey.general.language"))) {
                // No argument, which means DragonLanguage.selectable — all seven locales the kit
                // ships. That is correct again as of 2.12.0, because KeyKey now ships all seven
                // itself: App/{en,es,fr,ja,ko,zh-Hans,zh-Hant}.lproj.
                //
                // It was NOT correct through 2.11.4, when this same bare call shipped against two
                // .lproj — Settings offered Español, Français, 日本語, 한국어 and 简体中文, and
                // choosing one translated the shared panes while every KeyKey string fell back to
                // English. 2.11.5 narrowed it to `languages: [.en, .zhHant]`, which was the honest
                // list for a two-language app; this release closes the gap the other way instead,
                // so the narrowing is no longer needed.
                //
                // Bare rather than a literal seven, so the day the kit adds an eighth locale the
                // picker offers it and the checks below fail loudly, instead of a stale list
                // quietly hiding a language KeyKey has not translated yet. What keeps that honest:
                // ConfigContentTests' testLanguagePickerOffersExactlyTheShippedLocalizations, and
                // DragonKit CONFORMANCE §R13, which compares this call site against App/*.lproj
                // for every Dragon app rather than only this one.
                //
                // No onChange: it exists for apps whose own strings cannot switch live (ice-2
                // mirrors the choice into AppleLanguages and relaunches). Every KeyKey string is
                // read through L(), which dragonLocalized() re-resolves in place, so there is
                // nothing to relaunch for.
                LanguagePicker()
            }
        }
    }

    // Shared, not @State: the pane is rebuilt whenever the language changes, and a fresh model
    // would lose the result of an install still waiting on its password prompt.
    private var installation: InstallationModel { .shared }
}

// The 安裝 section: where this copy is installed, and the one-shot move to /Library/Input Methods
// that keeps KeyKey usable while another app holds secure input (see SystemInstall).
private struct InstallationRow: View {
    @Bindable var model: InstallationModel

    var body: some View {
        switch model.location {
        case .allUsers:
            Text(L("keykey.general.installedForAllUsers"))
                .dragonAnnotation(LocalizedStringKey(L("keykey.general.installedForAllUsersHint")))
        case .homebrew:
            Text(L("keykey.general.installedWithHomebrew"))
                .dragonAnnotation(LocalizedStringKey(L("keykey.general.installedWithHomebrewHint")))
        case .currentUser:
            Button(L("keykey.general.installForAllUsers")) { model.alert = .confirm }
                .disabled(model.isInstalling)
                .dragonAnnotation(LocalizedStringKey(L("keykey.general.installForAllUsersHint")))
                // One alert driven by one value: stacking several .alert modifiers on a view drops
                // all but one (the same reason BackupSettingsPane carries its notice as data).
                .alert(model.alert.map(Self.title) ?? "",
                       isPresented: Binding(get: { model.alert != nil },
                                            set: { if !$0 { model.alert = nil } }),
                       presenting: model.alert) { alert in
                    switch alert {
                    case .confirm:
                        Button(L("keykey.general.installConfirm")) { Task { await model.install() } }
                        Button(L("DragonKit.cancel"), role: .cancel) {}
                    case .failed:
                        Button(L("DragonKit.ok")) {}
                    case .oldCopyLeft(_, let newCopy):
                        Button(L("DragonKit.ok")) { SystemInstall.relaunch(from: newCopy) }
                    }
                } message: { alert in
                    Text(Self.message(alert))
                }
        case .elsewhere:
            EmptyView()
        }
    }

    private static func title(_ alert: InstallationModel.Alert) -> String {
        switch alert {
        case .confirm: L("keykey.general.installConfirmTitle")
        case .failed: L("keykey.general.installFailedTitle")
        case .oldCopyLeft: L("keykey.general.installOldCopyTitle")
        }
    }

    private static func message(_ alert: InstallationModel.Alert) -> String {
        switch alert {
        case .confirm: L("keykey.general.installConfirmMessage")
        case .failed(let detail): String(format: L("keykey.general.installFailedMessage"), detail)
        case .oldCopyLeft(let path, _): String(format: L("keykey.general.installOldCopyMessage"), path)
        }
    }
}

@MainActor
@Observable
private final class InstallationModel {
    static let shared = InstallationModel()

    enum Alert {
        case confirm
        case failed(String)
        /// Installed, but the per-user copy could not be removed: say where it is, then hand over.
        case oldCopyLeft(path: String, newCopy: URL)
    }

    let location: SystemInstall.Location
    private(set) var isInstalling = false
    var alert: Alert?

    private init() {
        let bundle = Bundle.main.bundleURL.standardizedFileURL
        location = SystemInstall.location(
            ofBundleAt: bundle.path,
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            homebrewTargets: SystemInstall.homebrewTargets(cask: SystemInstall.homebrewCask,
                                                           appName: bundle.lastPathComponent))
    }

    func install() async {
        guard !isInstalling else { return }
        isInstalling = true
        defer { isInstalling = false }
        let bundle = Bundle.main.bundleURL.standardizedFileURL
        switch await SystemInstall.installCopy(of: bundle, prompt: L("keykey.general.installPrompt")) {
        case .cancelled:
            break
        case .failed(let detail):
            alert = .failed(detail)
        case .signatureUnreadable:
            alert = .failed(L("keykey.general.installSignatureUnreadable"))
        case .installed:
            let newCopy = URL(fileURLWithPath: SystemInstall.directory, isDirectory: true)
                .appendingPathComponent(bundle.lastPathComponent, isDirectory: true)
            // Exactly one copy may carry the bundle id: with two, macOS may launch either, and
            // DragonKit's uninstaller refuses to run at all. The new copy is a verified duplicate,
            // so the old one is removed outright rather than left in the Trash, where it would
            // still count as a second copy.
            do {
                try FileManager.default.removeItem(at: bundle)
                SystemInstall.relaunch(from: newCopy)
            } catch {
                alert = .oldCopyLeft(path: bundle.path, newCopy: newCopy)
            }
        }
    }
}
