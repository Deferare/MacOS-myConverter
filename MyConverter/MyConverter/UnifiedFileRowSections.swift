#if os(macOS)
import SwiftUI

struct UnifiedFileRowSourceSection: View {
    let sourceURL: URL
    let order: Int
    let decorativeGlass: Glass

    var body: some View {
        HStack(spacing: UnifiedFileRowStyle.Metrics.titleSpacing) {
            Text("\(order)")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .glassEffect(decorativeGlass, in: Capsule())
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

            UnifiedFileRowThumbnailView(
                sourceURL: sourceURL,
                size: CGSize(
                    width: UnifiedFileRowStyle.Metrics.thumbnailWidth,
                    height: UnifiedFileRowStyle.Metrics.thumbnailHeight
                ),
                cornerRadius: UnifiedFileRowStyle.Metrics.thumbnailCornerRadius,
                borderOpacity: UnifiedFileRowStyle.Metrics.thumbnailBorderOpacity
            )
            .fixedSize()

            Text(sourceURL.lastPathComponent)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}

struct UnifiedFileRowOutputSection: View {
    let rowStatus: ContentViewModel.SelectedFileListState.RowStatus
    let displayedCompletedOutputURL: URL?
    let completedActionsTransition: AnyTransition
    let actionLabelColor: Color
    let actionButtonFillColor: Color
    let actionButtonBorderColor: Color

    var body: some View {
        HStack(spacing: UnifiedFileRowStyle.Metrics.outputSectionSpacing) {
            if let outputURL = displayedCompletedOutputURL {
                UnifiedFileRowCompletedActionsView(
                    url: outputURL,
                    spacing: UnifiedFileRowStyle.Metrics.outputSectionSpacing,
                    buttonHeight: UnifiedFileRowStyle.Metrics.completedActionHeight,
                    labelColor: actionLabelColor,
                    fillColor: actionButtonFillColor,
                    borderColor: actionButtonBorderColor
                )
                .transition(completedActionsTransition)
            } else if case .skipped = rowStatus {
                UnifiedFileRowStatusPlaceholderView(title: "Skipped", color: .orange)
            }
        }
        .padding(.leading, outputSectionLeadingPadding)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private var outputSectionLeadingPadding: CGFloat {
        switch rowStatus {
        case .completed, .skipped:
            return UnifiedFileRowStyle.Metrics.outputSectionSpacing
        case .pending, .converting:
            return 0
        }
    }
}

struct UnifiedFileRowStatusIndicator: View {
    let rowStatus: ContentViewModel.SelectedFileListState.RowStatus

    var body: some View {
        Image(systemName: rowStatus.statusAppearance.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(rowStatus.statusAppearance.color)
            .frame(width: UnifiedFileRowStyle.Metrics.statusIndicatorWidth)
    }
}

struct UnifiedFileRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }
}
#endif
