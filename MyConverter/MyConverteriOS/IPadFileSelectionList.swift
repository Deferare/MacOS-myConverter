#if os(iOS)
import SwiftUI

struct IPadFileRow: View {
    private enum Metrics {
        static let rowSpacing: CGFloat = 10
        static let rowHorizontalPadding: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 12
        static let rowCornerRadius: CGFloat = 16
        static let badgeHorizontalPadding: CGFloat = 5
        static let badgeVerticalPadding: CGFloat = 3
        static let titleSpacing: CGFloat = 8
        static let thumbnailHeight: CGFloat = 28
        static let accessorySpacing: CGFloat = 8
        static let progressBarHeight: CGFloat = 6
    }

    let kind: ContentViewModel.MediaKind
    let url: URL
    let order: Int
    let rowStatus: ContentViewModel.SelectedFileListState.RowStatus
    let thumbnailProvider: any ThumbnailProvider

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            HStack(spacing: 0) {
                sourceSection
                outputSection
                statusIndicator
            }
            .frame(minHeight: Metrics.thumbnailHeight)

            if rowStatus.showsProgressBar {
                ProgressView(value: rowStatus.progressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(rowStatus.statusAppearance.color)
                    .frame(height: Metrics.progressBarHeight)
                    .transition(progressTransition)
            }
        }
        .padding(.horizontal, Metrics.rowHorizontalPadding)
        .padding(.vertical, Metrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: rowStatus.showsProgressBar)
    }

    private var sourceSection: some View {
        HStack(spacing: Metrics.titleSpacing) {
            Text("\(order)")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Metrics.badgeHorizontalPadding)
                .padding(.vertical, Metrics.badgeVerticalPadding)
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
                fallbackSystemImage: fallbackSystemImage
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

    @ViewBuilder
    private var outputSection: some View {
        switch rowStatus {
        case .completed:
            statusPill(title: "Saved", color: .green)
                .padding(.leading, Metrics.accessorySpacing)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        case .skipped:
            statusPill(title: "Skipped", color: .orange)
                .padding(.leading, Metrics.accessorySpacing)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        case .pending, .converting:
            EmptyView()
        }
    }

    private var statusIndicator: some View {
        Image(systemName: rowStatus.statusAppearance.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(rowStatus.statusAppearance.color)
            .frame(width: 36)
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

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var progressTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        )
    }

    private var fallbackSystemImage: String {
        kind.descriptor.sidebarSystemImage
    }
}

private struct IPadThumbnailView: View {
    private enum Metrics {
        static let width: CGFloat = 40
        static let height: CGFloat = 28
        static let cornerRadius: CGFloat = 8
        static let borderOpacity: CGFloat = 0.12
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
                placeholderThumbnail
            }
        }
        .frame(width: Metrics.width, height: Metrics.height)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .stroke(.white.opacity(Metrics.borderOpacity), lineWidth: 1)
        )
        .task(id: url) {
            cgImage = await provider.makeThumbnail(
                for: url,
                size: CGSize(width: Metrics.width * 2, height: Metrics.height * 2)
            )
        }
    }

    private var placeholderThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(.white.opacity(0.05))

            Image(systemName: fallbackSystemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
#endif
