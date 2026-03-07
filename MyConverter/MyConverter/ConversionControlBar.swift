import SwiftUI

struct ConversionToolbarButton: View {
    let isConverting: Bool
    let canConvert: Bool
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if isConverting {
            Button("Cancel", action: onCancel)
                .controlSize(.regular)
                .tint(nil)
        } else {
            Button("Start", action: onStart)
                .controlSize(.regular)
                .tint(nil)
                .disabled(!canConvert)
        }
    }
}
