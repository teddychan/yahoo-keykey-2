import SwiftUI
import DragonKit

// KeyKey's General settings pane: the real input toggles (輸出簡體字 / 全形標點 / 聯想字詞 and the
// 聯想只顯示接續字 option), the candidate font size, the 倉頡版本 picker, and the shared language
// picker. Everything binds to `SettingsModel`, which forwards to the live `Preferences` the
// engine reads — so changes apply on the next composition, no restart.
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
            }

            DragonSection(LocalizedStringKey(L("keykey.general.language"))) {
                LanguagePicker()
            }
        }
    }
}
