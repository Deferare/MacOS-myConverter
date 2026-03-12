#if os(iOS)
import SwiftUI

struct IPadFileRow: View {
    private enum Metrics {
        static let rowSpacing: CGFloat = 12
        static let rowPadding: CGFloat = 12
        static let rowCornerRadius: CGFloat = 18
        static let badgeSize: CGFloat = 24
        static let badgeCornerRadius: CGFloat = 9
        static let thumbnailSize: CGFloat = 48
        static let thumbnailCornerRadius: CGFloat = 14
        static let detailSpacing: CGFloat = 4
        static let progressWidth: CGFloat = 82
        static let badgeBackgroundOpacity: CGFloat = 0.18
        static let badgeBorderOpacity: CGFloat = 0.08
        static let badgeFont = Font.caption.weight(.semibold)
        static let titleFont = Font.subheadline.weight(.semibold)
    }

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
        HStack(spacing: Metrics.rowSpacing) {
            Text(fileIndexLabel)
                .font(Metrics.badgeFont)
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: Metrics.badgeSize, height: Metrics.badgeSize)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.badgeCornerRadius, style: .continuous)
                        .fill(.black.opacity(Metrics.badgeBackgroundOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: Metrics.badgeCornerRadius, style: .continuous)
                                .stroke(.white.opacity(Metrics.badgeBorderOpacity), lineWidth: 1)
                        )
                )

            IPadThumbnailView(
                url: url,
                provider: thumbnailProvider,
                fallbackSystemImage: fallbackSystemImage
            )

            VStack(alignment: .leading, spacing: Metrics.detailSpacing) {
                Text(url.lastPathComponent)
                    .font(Metrics.titleFont)
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
                        .frame(width: Metrics.progressWidth)
                    Text("\(Int((progressValue * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Metrics.rowPadding)
        .background(
            .white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
        )
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
    private enum Metrics {
        static let size: CGFloat = 48
        static let cornerRadius: CGFloat = 14
    }

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
        .frame(width: Metrics.size, height: Metrics.size)
        .background(
            .white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .task(id: url) {
            cgImage = await provider.makeThumbnail(
                for: url,
                size: CGSize(width: Metrics.size * 2, height: Metrics.size * 2)
            )
        }
    }
}
#endif
