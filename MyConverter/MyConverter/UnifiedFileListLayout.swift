#if os(macOS)
import AppKit
import SwiftUI

struct UnifiedFileListRowDescriptor: Identifiable {
    let url: URL
    let order: Int
    let rowStatus: ContentViewModel.SelectedFileListState.RowStatus

    var id: String {
        url.path
    }
}

struct UnifiedFileListLayout {
    private enum Metrics {
        static let containerSpacing: CGFloat = 14
        static let rowSpacing: CGFloat = 8
        static let contentPadding: CGFloat = 20
        static let headerHeight: CGFloat = 56
    }

    let fileDropAreaHeight: CGFloat
    let rowDescriptors: [UnifiedFileListRowDescriptor]

    static var containerSpacing: CGFloat {
        Metrics.containerSpacing
    }

    static var rowSpacing: CGFloat {
        Metrics.rowSpacing
    }

    static var contentPadding: CGFloat {
        Metrics.contentPadding
    }

    var visibleRowsHeight: CGFloat {
        min(totalRowsHeight, maximumScrollHeight)
    }

    var populatedListHeight: CGFloat {
        let contentHeight = Metrics.headerHeight + Metrics.containerSpacing + visibleRowsHeight
        return min(fileDropAreaHeight, (Metrics.contentPadding * 2) + contentHeight)
    }

    private var maximumScrollHeight: CGFloat {
        max(
            0,
            fileDropAreaHeight - (Metrics.contentPadding * 2) - Metrics.headerHeight - Metrics.containerSpacing
        )
    }

    private var totalRowsHeight: CGFloat {
        guard !rowDescriptors.isEmpty else {
            return 0
        }

        let rowHeights = rowDescriptors.map { descriptor in
            UnifiedFileRowView.estimatedHeight(for: descriptor.rowStatus)
        }

        return rowHeights.reduce(0, +) + (CGFloat(rowDescriptors.count - 1) * Metrics.rowSpacing)
    }
}
#endif
