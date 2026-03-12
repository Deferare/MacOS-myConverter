import SwiftUI

struct ConverterFormSections<SettingsContent: View>: View {
    let isConverting: Bool
    let settingsContent: SettingsContent

    init(
        isConverting: Bool,
        @ViewBuilder settingsContent: () -> SettingsContent
    ) {
        self.isConverting = isConverting
        self.settingsContent = settingsContent()
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsContent
        }
        .disabled(isConverting)
    }
}
