#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IPadFileSelectionList: View {
    private struct RowDescriptor: Identifiable {
        let url: URL
        let order: Int
        let rowStatus: ContentViewModel.SelectedFileListState.RowStatus

        var id: String {
            url.path
        }
    }

    private enum Metrics {
        static let containerSpacing: CGFloat = 16
        static let rowSpacing: CGFloat = 8
    }

    let kind: ContentViewModel.MediaKind
    let state: ContentViewModel.SelectedFileListState
    let inputHeaderState: ContentViewModel.ConverterInputHeaderState
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let thumbnailProvider: any ThumbnailProvider
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    var body: some View {
        let rowDescriptors = makeRowDescriptors()
        let availableURLPaths = Set(rowDescriptors.map(\.url.path))

        return VStack(alignment: .leading, spacing: Metrics.containerSpacing) {
            headerBar

            LazyVStack(spacing: Metrics.rowSpacing) {
                ForEach(rowDescriptors) { row in
                    IPadFileRow(
                        kind: kind,
                        url: row.url,
                        order: row.order,
                        rowStatus: row.rowStatus,
                        thumbnailProvider: thumbnailProvider
                    )
                    .onDrag {
                        guard !state.isConverting else {
                            return NSItemProvider()
                        }

                        draggedSelectedFileURL = row.url
                        return NSItemProvider(object: NSString(string: row.url.path))
                    }
                    .onDrop(
                        of: [.text],
                        delegate: SelectedFileReorderDropDelegate(
                            targetURL: row.url,
                            availableURLPaths: availableURLPaths,
                            draggedURL: $draggedSelectedFileURL,
                            isEnabled: !state.isConverting,
                            onMove: { draggedURL, targetURL in
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    onReorder(draggedURL, targetURL)
                                }
                            }
                        )
                    )
                }
            }
        }
    }

    private func makeRowDescriptors() -> [RowDescriptor] {
        state.selectedURLs.enumerated().map { index, url in
            RowDescriptor(
                url: url,
                order: index + 1,
                rowStatus: state.rowStatus(for: url)
            )
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Files")
                .font(.headline.weight(.semibold))

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)

                    Text(inputHeaderState.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                if state.isConverting {
                    Text(inputHeaderState.progressText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(isDropTargeted ? "Release to add files" : "Drag to reorder or drop more files here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusColor: Color {
        inputHeaderState.statusLevel.color
    }
}
#endif
