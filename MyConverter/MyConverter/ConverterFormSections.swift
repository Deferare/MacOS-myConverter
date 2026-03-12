import SwiftUI

struct ConverterFormSections<SettingsContent: View>: View {
    let isConverting: Bool
    let settingsContent: SettingsContent
    @Environment(\.converterSettingMetrics) private var metrics

    init(
        isConverting: Bool,
        @ViewBuilder settingsContent: () -> SettingsContent
    ) {
        self.isConverting = isConverting
        self.settingsContent = settingsContent()
    }

    var body: some View {
        VStack(spacing: metrics.sectionSpacing) {
            settingsContent
        }
        .disabled(isConverting)
    }
}
