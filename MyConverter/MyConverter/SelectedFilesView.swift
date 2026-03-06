import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SelectedFilesView: View {
    let urls: [URL]
    let systemImage: String
    let isConverting: Bool
    let fileDropAreaHeight: CGFloat
    @Binding var draggedSelectedFileURL: URL?
    let onImport: () -> Void
    let onClear: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("Selected Files")
                    .font(.headline)

                Text("\(urls.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                        SelectedFileCardView(
                            url: url,
                            order: index + 1,
                            systemImage: systemImage
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
                                urls: urls,
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
            }

            HStack {
                Text(isConverting ? "Ready for conversion" : "Ready for conversion · Drag cards to reorder")
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
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: fileDropAreaHeight, maxHeight: fileDropAreaHeight)
        .background(ConverterInputAreaBackground(isDropTargeted: false, usesDashedBorder: false))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
