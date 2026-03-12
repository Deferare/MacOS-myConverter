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

                HStack(spacing: 8) {
                    tag(url.pathExtension.isEmpty ? "Source" : url.pathExtension.uppercased())

                    if isProcessed {
                        tag("Done", tone: .green)
                    } else if selectedFileListState.isConverting {
                        tag("Active", tone: .orange)
                    }
                }

                if let outputURL {
                    Text("Output: \(outputURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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

    private func tag(_ text: String, tone: Color = .secondary) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tone.opacity(0.12), in: Capsule())
    }
}

struct IPadResultRow: View {
    let url: URL
    let kind: ContentViewModel.MediaKind
    let thumbnailProvider: any ThumbnailProvider

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

                Text("Saved output")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var fallbackSystemImage: String {
        switch kind {
        case .video:
            return "play.rectangle"
        case .image:
            return "photo.on.rectangle"
        case .audio:
            return "waveform.circle"
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
