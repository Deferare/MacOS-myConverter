#if os(iOS)
import SwiftUI

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

    private var fileIndexLabel: String {
        guard let index = selectedFileListState.selectedURLs.firstIndex(of: url) else {
            return "-"
        }
        return String(index + 1)
    }

    private var detailText: String {
        if let outputURL {
            return outputURL.lastPathComponent
        }
        if isProcessed {
            return "Ready"
        }
        if selectedFileListState.isConverting {
            return "Converting..."
        }
        return url.pathExtension.isEmpty ? "Source file" : url.pathExtension.uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(fileIndexLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            IPadThumbnailView(
                url: url,
                provider: thumbnailProvider,
                fallbackSystemImage: fallbackSystemImage
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if selectedFileListState.isConverting {
                VStack(alignment: .trailing, spacing: 6) {
                    ProgressView(value: progressValue)
                        .frame(width: 90)
                    Text("\(Int((progressValue * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
