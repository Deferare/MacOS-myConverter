import SwiftUI

struct ConversionControlBar: View {
    let statusMessage: String
    let statusColor: Color
    let progress: Double
    let progressText: String
    let progressTint: Color
    let isConverting: Bool
    let canConvert: Bool
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text(statusMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(progressText)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(progressTint)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .clipShape(Capsule())
                    .animation(.spring(), value: progress)
            }

            Button {
                if isConverting {
                    onCancel()
                } else {
                    onStart()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isConverting ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .black))
                    Text(isConverting ? "Cancel" : "Start Conversion")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(minWidth: 150, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isConverting ? false : !canConvert)
            .shadow(
                color: (isConverting || canConvert) ? Color.accentColor.opacity(0.2) : .clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
    }
}

extension ContentViewModel.ConversionStatusLevel {
    var color: Color {
        switch self {
        case .normal:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
