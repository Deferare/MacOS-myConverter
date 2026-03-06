import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct UnifiedFileListView: View {
    let sourceURLs: [URL]
    let outputURLs: [URL]
    let systemImage: String
    let dropPlaceholder: String
    let isConverting: Bool
    let currentBatchIndex: Int
    let fileDropAreaHeight: CGFloat
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let onImport: () -> Void
    let onClear: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    var body: some View {
        Group {
            if !isDropTargeted, !sourceURLs.isEmpty {
                populatedListView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                DropFileView(
                    isDropTargeted: isDropTargeted,
                    placeholder: dropPlaceholder,
                    fileDropAreaHeight: fileDropAreaHeight,
                    action: onImport
                )
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }
        }
    }

    // MARK: - Populated List

    private var populatedListView: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBar

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 8) {
                    ForEach(Array(sourceURLs.enumerated()), id: \.element.path) { index, url in
                        let outputURL = index < outputURLs.count ? outputURLs[index] : nil
                        let isCurrentItem = isConverting && (index + 1) == currentBatchIndex

                        UnifiedFileRowView(
                            sourceURL: url,
                            outputURL: outputURL,
                            order: index + 1,
                            systemImage: systemImage,
                            isConverting: isConverting,
                            isCurrentlyConverting: isCurrentItem
                        )
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
                                urls: sourceURLs,
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

            footerBar
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

            Text("\(sourceURLs.count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))

            if !outputURLs.isEmpty {
                completionBadge
            }

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

    private var completionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)

            Text("\(outputURLs.count)/\(sourceURLs.count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.green.opacity(0.1)))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Text(footerText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onImport) {
                Label("Add Files", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isConverting)
        }
    }

    private var footerText: String {
        if isConverting {
            return "Converting \(currentBatchIndex) of \(sourceURLs.count)…"
        } else if !outputURLs.isEmpty && outputURLs.count == sourceURLs.count {
            return "All files converted successfully"
        } else if !outputURLs.isEmpty {
            return "\(outputURLs.count) of \(sourceURLs.count) converted"
        } else {
            return "Ready for conversion · Drag rows to reorder"
        }
    }
}
