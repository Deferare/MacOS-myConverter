#if os(macOS)
import AppKit
import SwiftUI

struct UnifiedFileListHeaderView: View {
    let inputHeaderState: ContentViewModel.ConverterInputHeaderState
    let isDropTargeted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Files")
                    .font(.headline)

                Spacer()
            }

            HStack(spacing: 12) {
                statusMessageView

                Spacer()

                if inputHeaderState.isConverting {
                    Text(inputHeaderState.progressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(isDropTargeted ? "Release to add files" : "Drag to reorder or drop more files here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusMessageView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(inputHeaderState.statusLevel.color)
                .frame(width: 8, height: 8)

            Text(inputHeaderState.statusMessage)
                .font(.subheadline)
                .foregroundStyle(inputHeaderState.statusLevel.color)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
#endif
