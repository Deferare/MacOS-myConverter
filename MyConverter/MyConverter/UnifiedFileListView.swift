import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct UnifiedFileListView: View {
    let sourceURLs: [URL]
    let outputURLsBySourceID: [String: URL]
    let processedSourceIDs: Set<String>
    let systemImage: String
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
        let availableURLPaths = Set(sourceURLs.map(\.path))

        return VStack(alignment: .leading, spacing: 14) {
            headerBar

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    ForEach(Array(sourceURLs.enumerated()), id: \.element.path) { index, url in
                        let sourceID = ContentViewModelSupport.sourceIdentifier(for: url)

                        UnifiedFileRowView(
                            sourceURL: url,
                            order: index + 1,
                            systemImage: systemImage,
                            rowState: rowState(for: sourceID, order: index + 1)
                        )
                        .equatable()
                        .transition(.identity)
                        .onDrag {
                            guard !isConverting else {
                                return NSItemProvider()
                            }
                            draggedSelectedFileURL = url
                            return NSItemProvider(object: NSString(string: url.path))
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: SelectedFileReorderDropDelegate(
                                targetURL: url,
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

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            Text("Files")
                .font(.headline)

            Spacer()

            if !isConverting {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
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
