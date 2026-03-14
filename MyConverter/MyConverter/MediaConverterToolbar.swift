#if os(macOS)
import AppKit
import SwiftUI

struct MediaConverterToolbarContent: ToolbarContent {
    let kind: ContentViewModel.MediaKind
    let screenState: ContentViewModel.ConverterScreenState
    let utilityTint: Color
    let clearAnimation: Animation
    let onClear: () -> Void
    let onImport: () -> Void
    let onPrimaryAction: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if screenState.selectedFileCount > 0 {
            ToolbarItemGroup(placement: .primaryAction) {
                if !screenState.isConverting {
                    Button {
                        withAnimation(clearAnimation) {
                            onClear()
                        }
                    } label: {
                        Label("Clear Files", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .tint(utilityTint)
                    .help("Clear Files")

                    Button("Add Files", systemImage: "plus") {
                        onImport()
                    }
                    .tint(utilityTint)
                }

                Button(action: onPrimaryAction) {
                    Text(screenState.primaryActionTitle)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(kind.liquidGlassTint)
                .disabled(!screenState.isConverting && !screenState.canConvert)
            }
        }
    }
}
#endif
