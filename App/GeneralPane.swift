import SwiftUI
import DragonKit

// KeyKey's General settings pane: the real input toggles (輸出簡體字 / 全形標點 / 聯想字詞 and the
// 聯想只顯示接續字 option), the candidate font size, the 倉頡版本 picker and 以空白鍵確認字根
// toggle, and the shared language picker. Everything binds to `SettingsModel`, which forwards
// to the live `Preferences` the engine reads — so changes apply on the next composition, no restart.
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
            DragonSection(LocalizedStringKey(L("keykey.general.input"))) {
                Toggle(L("keykey.general.outputSimplified"), isOn: $model.outputSimplified)
                Toggle(L("keykey.general.fullWidthPunctuation"), isOn: $model.fullWidthPunctuation)
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
                Toggle(L("keykey.general.strokeConfirmation"), isOn: $model.strokeConfirmation)
                    .dragonAnnotation(LocalizedStringKey(L("keykey.general.strokeConfirmationHint")))
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
}
