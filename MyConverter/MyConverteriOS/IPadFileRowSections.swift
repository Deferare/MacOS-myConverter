#if os(iOS)
import SwiftUI

struct IPadFileRowSourceSection: View {
    let kind: ContentViewModel.MediaKind
    let url: URL
    let order: Int
    let thumbnailProvider: any ThumbnailProvider

    var body: some View {
        HStack(spacing: IPadFileRowStyle.Metrics.titleSpacing) {
            Text("\(order)")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, IPadFileRowStyle.Metrics.badgeHorizontalPadding)
                .padding(.vertical, IPadFileRowStyle.Metrics.badgeVerticalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.06))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .fixedSize(horizontal: true, vertical: false)

            IPadThumbnailView(
                url: url,
                provider: thumbnailProvider,
                fallbackSystemImage: kind.sidebarSystemImage
            )
            .fixedSize()

            Text(url.lastPathComponent)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}

struct IPadFileRowOutputSection: View {
    let rowStatus: ContentViewModel.SelectedFileListState.RowStatus

    var body: some View {
        Group {
            switch rowStatus {
            case .completed:
                statusPill(title: "Saved", color: .green)
                    .padding(.leading, IPadFileRowStyle.Metrics.accessorySpacing)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            case .skipped:
                statusPill(title: "Skipped", color: .orange)
                    .padding(.leading, IPadFileRowStyle.Metrics.accessorySpacing)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            case .pending, .converting:
                EmptyView()
            }
        }
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(color.opacity(0.18), lineWidth: 1)
                    )
            )
    }
}

struct IPadFileRowStatusIndicator: View {
    let rowStatus: ContentViewModel.SelectedFileListState.RowStatus

    var body: some View {
        Image(systemName: rowStatus.statusAppearance.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(rowStatus.statusAppearance.color)
            .frame(width: IPadFileRowStyle.Metrics.statusIndicatorWidth)
    }
}

struct IPadThumbnailView: View {
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
                placeholderThumbnail
            }
        }
        .frame(
            width: IPadFileRowStyle.Metrics.thumbnailWidth,
            height: IPadFileRowStyle.Metrics.thumbnailHeight
        )
        .background(
            RoundedRectangle(
                cornerRadius: IPadFileRowStyle.Metrics.thumbnailCornerRadius,
                style: .continuous
            )
            .fill(.white.opacity(0.05))
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: IPadFileRowStyle.Metrics.thumbnailCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: IPadFileRowStyle.Metrics.thumbnailCornerRadius,
                style: .continuous
            )
            .stroke(.white.opacity(IPadFileRowStyle.Metrics.thumbnailBorderOpacity), lineWidth: 1)
        )
        .task(id: url) {
            cgImage = await provider.makeThumbnail(
                for: url,
                size: CGSize(
                    width: IPadFileRowStyle.Metrics.thumbnailWidth * 2,
                    height: IPadFileRowStyle.Metrics.thumbnailHeight * 2
                )
            )
        }
    }

    private var placeholderThumbnail: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: IPadFileRowStyle.Metrics.thumbnailCornerRadius,
                style: .continuous
            )
            .fill(.white.opacity(0.05))

            Image(systemName: fallbackSystemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
#endif
