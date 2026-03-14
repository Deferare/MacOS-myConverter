import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct UnifiedFileListView: View {
    let state: ContentViewModel.SelectedFileListState
    let dropPlaceholder: String
    let fileDropAreaHeight: CGFloat
    let isDropTargeted: Bool
    let inputHeaderState: ContentViewModel.ConverterInputHeaderState
    @Binding var draggedSelectedFileURL: URL?
    let onImport: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    private let contentTransition: AnyTransition = .identity

    var body: some View {
        Group {
            if state.selectedURLs.isEmpty {
                DropFileView(
                    isDropTargeted: isDropTargeted,
                    placeholder: dropPlaceholder,
                    fileDropAreaHeight: fileDropAreaHeight,
                    action: onImport
                )
                .transition(contentTransition)
            } else {
                populatedListView
                    .transition(contentTransition)
            }
        }
    }

    // MARK: - Populated List

    private var populatedListView: some View {
        let rowDescriptors = makeRowDescriptors()
        let availableURLPaths = Set(rowDescriptors.map(\.url.path))
        let layout = UnifiedFileListLayout(
            fileDropAreaHeight: fileDropAreaHeight,
            rowDescriptors: rowDescriptors
        )

        return VStack(alignment: .leading, spacing: UnifiedFileListLayout.containerSpacing) {
            UnifiedFileListHeaderView(
                inputHeaderState: inputHeaderState,
                isDropTargeted: isDropTargeted
            )

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: UnifiedFileListLayout.rowSpacing) {
                    ForEach(rowDescriptors) { row in
                        UnifiedFileRowView(
                            sourceURL: row.url,
                            order: row.order,
                            rowStatus: row.rowStatus
                        )
                        .equatable()
                        .transition(.identity)
                        .onDrag {
                            guard !state.isConverting else {
                                return NSItemProvider()
                            }
                            draggedSelectedFileURL = row.url
                            return NSItemProvider(object: NSString(string: row.url.path))
                        }
                        .onDrop(
                            of: [UTType.text],
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: layout.visibleRowsHeight)
        }
        .padding(UnifiedFileListLayout.contentPadding)
        .frame(maxWidth: .infinity)
        .frame(height: layout.populatedListHeight)
        .background(ConverterInputAreaBackground(isDropTargeted: isDropTargeted, usesDashedBorder: false))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func makeRowDescriptors() -> [UnifiedFileListRowDescriptor] {
        state.selectedURLs.enumerated().map { index, url in
            return UnifiedFileListRowDescriptor(
                url: url,
                order: index + 1,
                rowStatus: state.rowStatus(for: url)
            )
        }
    }
}
