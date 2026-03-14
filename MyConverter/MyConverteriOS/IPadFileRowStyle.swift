#if os(iOS)
import SwiftUI

enum IPadFileRowStyle {
    enum Metrics {
        static let rowSpacing: CGFloat = 10
        static let rowHorizontalPadding: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 12
        static let rowCornerRadius: CGFloat = 16
        static let badgeHorizontalPadding: CGFloat = 5
        static let badgeVerticalPadding: CGFloat = 3
        static let titleSpacing: CGFloat = 8
        static let thumbnailWidth: CGFloat = 40
        static let thumbnailHeight: CGFloat = 28
        static let thumbnailCornerRadius: CGFloat = 8
        static let thumbnailBorderOpacity: CGFloat = 0.12
        static let accessorySpacing: CGFloat = 8
        static let progressBarHeight: CGFloat = 6
        static let statusIndicatorWidth: CGFloat = 36
    }

    static var progressTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        )
    }
}

struct IPadFileRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: IPadFileRowStyle.Metrics.rowCornerRadius, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: IPadFileRowStyle.Metrics.rowCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }
}
#endif
