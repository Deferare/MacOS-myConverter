#if os(iOS)
import SwiftUI

struct IPadMediaConverterToolbarContent<ImportControl: View>: ToolbarContent {
    let screenState: ContentViewModel.ConverterScreenState
    let selectedURLs: [URL]
    let utilityTint: Color
    let actionTint: Color
    let onClear: () -> Void
    let onPrimaryAction: () -> Void
    let importControl: ImportControl

    init(
        screenState: ContentViewModel.ConverterScreenState,
        selectedURLs: [URL],
        utilityTint: Color,
        actionTint: Color,
        onClear: @escaping () -> Void,
        onPrimaryAction: @escaping () -> Void,
        @ViewBuilder importControl: () -> ImportControl
    ) {
        self.screenState = screenState
        self.selectedURLs = selectedURLs
        self.utilityTint = utilityTint
        self.actionTint = actionTint
        self.onClear = onClear
        self.onPrimaryAction = onPrimaryAction
        self.importControl = importControl()
    }

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if screenState.selectedFileCount > 0 {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !screenState.isConverting {
                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .foregroundStyle(utilityTint)
                    }
                    .disabled(selectedURLs.isEmpty)

                    importControl
                }

                Button(action: onPrimaryAction) {
                    Text(screenState.primaryActionTitle)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(actionTint)
                .disabled(!screenState.isConverting && !screenState.canConvert)
            }
        }
    }
}
#endif
