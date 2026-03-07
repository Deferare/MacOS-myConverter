import SwiftUI

struct ConversionToolbarButton: View {
    let isConverting: Bool
    let canConvert: Bool
    let onStart: () -> Void
    let onCancel: () -> Void

    private var actionTitle: String {
        isConverting ? "Cancel" : "Start"
    }

    var body: some View {
        Button {
            if isConverting {
                onCancel()
            } else {
                onStart()
            }
        } label: {
            Text(actionTitle)
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .disabled(isConverting ? false : !canConvert)
    }
}
