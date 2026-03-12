#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IPadFileRow: View {
    let kind: ContentViewModel.MediaKind
    let url: URL
    let selectedFileListState: ContentViewModel.SelectedFileListState
    let thumbnailProvider: any ThumbnailProvider

    private var outputURL: URL? {
        let sourceID = ContentViewModelSupport.sourceIdentifier(for: url)
        return selectedFileListState.outputURLsBySourceID[sourceID]
    }

    private var isProcessed: Bool {
        let sourceID = ContentViewModelSupport.sourceIdentifier(for: url)
        return selectedFileListState.processedSourceIDs.contains(sourceID)
    }

    var body: some View {
        HStack(spacing: 14) {
            IPadThumbnailView(
                url: url,
                provider: thumbnailProvider,
                fallbackSystemImage: fallbackSystemImage
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(url.pathExtension.isEmpty ? "Original file" : url.pathExtension.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let outputURL {
                    Text("Output: \(outputURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if selectedFileListState.isConverting {
                ProgressView(value: progressValue)
                    .frame(width: 72)
            } else if isProcessed {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var progressValue: Double {
        if isProcessed {
            return 1
        }
        return selectedFileListState.currentItemProgress
    }

    private var fallbackSystemImage: String {
        switch kind {
        case .video:
            return "film"
        case .image:
            return "photo"
        case .audio:
            return "waveform"
        }
    }
}

private struct IPadThumbnailView: View {
    let url: URL
    let provider: any ThumbnailProvider
    let fallbackSystemImage: String
    @State private var cgImage: CGImage?

    var body: some View {
        Group {
            if let cgImage {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 54, height: 54)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: url) {
            cgImage = await provider.makeThumbnail(for: url, size: CGSize(width: 108, height: 108))
        }
    }
}
#endif
