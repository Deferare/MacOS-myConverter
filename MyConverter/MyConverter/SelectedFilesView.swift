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
        let availableURLPaths = Set(urls.map(\.path))

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("Selected Files")
                    .font(.headline)

                Text("\(urls.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.interactive(false), in: Capsule())

                Spacer()

                if !isConverting {
                    Button(action: onClear) {
                        Label("Clear Files", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .tint(.secondary)
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
            }

            HStack {
                Text(isConverting ? "Ready for conversion" : "Ready for conversion · Drag cards to reorder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onImport) {
                    Label("Add Files", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(isConverting)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: fileDropAreaHeight, maxHeight: fileDropAreaHeight)
        .background(ConverterInputAreaBackground(isDropTargeted: false, usesDashedBorder: false))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
