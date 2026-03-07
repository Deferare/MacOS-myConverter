import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct UnifiedFileListView: View {
    private struct RowDescriptor: Identifiable {
        let url: URL
        let order: Int
        let rowState: UnifiedFileRowView.RowState

        var id: String {
            url.path
        }
    }

    let sourceURLs: [URL]
    let outputURLsBySourceID: [String: URL]
    let processedSourceIDs: Set<String>
    let dropPlaceholder: String
    let isConverting: Bool
    let currentBatchIndex: Int
    let currentItemProgress: Double
    let fileDropAreaHeight: CGFloat
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let onImport: () -> Void
    let onClear: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    private let contentTransition: AnyTransition = .identity

    var body: some View {
        Group {
            if !isDropTargeted, !sourceURLs.isEmpty {
                populatedListView
                    .transition(contentTransition)
            } else {
                DropFileView(
                    isDropTargeted: isDropTargeted,
                    placeholder: dropPlaceholder,
                    fileDropAreaHeight: fileDropAreaHeight,
                    action: onImport
                )
                .transition(contentTransition)
            }
        }
    }

    // MARK: - Populated List

    private var populatedListView: some View {
        let rowDescriptors = makeRowDescriptors()
        let availableURLPaths = Set(rowDescriptors.map(\.url.path))

        return VStack(alignment: .leading, spacing: 14) {
            headerBar

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    ForEach(rowDescriptors) { row in
                        UnifiedFileRowView(
                            sourceURL: row.url,
                            order: row.order,
                            rowState: row.rowState
                        )
                        .equatable()
                        .transition(.identity)
                        .onDrag {
                            guard !isConverting else {
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
                                isEnabled: !isConverting,
                                onMove: { draggedURL, targetURL in
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        onReorder(draggedURL, targetURL)
                                    }
                                }
                            )
                        )
                    }
                }
                .padding(4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: fileDropAreaHeight, maxHeight: fileDropAreaHeight)
        .background(ConverterInputAreaBackground(isDropTargeted: false, usesDashedBorder: false))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func makeRowDescriptors() -> [RowDescriptor] {
        sourceURLs.enumerated().map { index, url in
            let order = index + 1
            let sourceID = ContentViewModelSupport.sourceIdentifier(for: url)

            return RowDescriptor(
                url: url,
                order: order,
                rowState: rowState(for: sourceID, order: order)
            )
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Text("Files")
                .font(.headline)

            Text("\(sourceURLs.count)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .glassEffect(.regular.interactive(false), in: Capsule())

            Spacer()

            if !isConverting {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: onClear) {
                            Label("Clear Files", systemImage: "xmark")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(.secondary)
                    }
                }
            }
        }
    }

    private func rowState(for sourceID: String, order: Int) -> UnifiedFileRowView.RowState {
        if let outputURL = outputURLsBySourceID[sourceID] {
            return .completed(outputURL)
        }

        if isConverting && order == currentBatchIndex {
            return .converting(progress: currentItemProgress)
        }

        if processedSourceIDs.contains(sourceID) {
            return .skipped
        }

        return .pending
    }
}
