#if os(macOS)
import SwiftUI

enum UnifiedFileRowStyle {
    enum Metrics {
        static let rowSpacing: CGFloat = 10
        static let rowHorizontalPadding: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 12
        static let progressBarHeight: CGFloat = 6
        static let titleSpacing: CGFloat = 6
        static let thumbnailWidth: CGFloat = 40
        static let thumbnailHeight: CGFloat = 28
        static let thumbnailCornerRadius: CGFloat = 8
        static let thumbnailBorderOpacity: CGFloat = 0.12
        static let outputSectionSpacing: CGFloat = 8
        static let primaryContentMinHeight: CGFloat = 26
        static let completedActionHeight: CGFloat = 30
        static let statusIndicatorWidth: CGFloat = 36
        static let completionAccessoryOffset: CGFloat = 12
        static let completionAccessoryRevealDelayNanoseconds: UInt64 = 180_000_000
        static let visibilityTransitionAnimation = Animation.spring(response: 0.24, dampingFraction: 0.86)
        static let progressAnimationDuration: Double = 0.06
    }

    static func estimatedHeight(
        for rowStatus: ContentViewModel.SelectedFileListState.RowStatus
    ) -> CGFloat {
        let baseHeight = primaryContentMinHeight(for: rowStatus) + (Metrics.rowVerticalPadding * 2)
        guard rowStatus.showsProgressBar else {
            return baseHeight
        }

        return baseHeight + Metrics.rowSpacing + Metrics.progressBarHeight
    }

    static func primaryContentMinHeight(
        for rowStatus: ContentViewModel.SelectedFileListState.RowStatus
    ) -> CGFloat {
        let sourceContentHeight = max(Metrics.primaryContentMinHeight, Metrics.thumbnailHeight)

        switch rowStatus {
        case .completed:
            return max(sourceContentHeight, Metrics.completedActionHeight)
        case .pending, .converting, .skipped:
            return sourceContentHeight
        }
    }
}
#endif
