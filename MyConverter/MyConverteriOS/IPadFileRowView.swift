#if os(iOS)
import SwiftUI

struct IPadFileRow: View {
    let kind: ContentViewModel.MediaKind
    let url: URL
    let order: Int
    let rowStatus: ContentViewModel.SelectedFileListState.RowStatus
    let thumbnailProvider: any ThumbnailProvider

    var body: some View {
        VStack(alignment: .leading, spacing: IPadFileRowStyle.Metrics.rowSpacing) {
            HStack(spacing: 0) {
                IPadFileRowSourceSection(
                    kind: kind,
                    url: url,
                    order: order,
                    thumbnailProvider: thumbnailProvider
                )
                IPadFileRowOutputSection(rowStatus: rowStatus)
                IPadFileRowStatusIndicator(rowStatus: rowStatus)
            }
            .frame(minHeight: IPadFileRowStyle.Metrics.thumbnailHeight)

            if rowStatus.showsProgressBar {
                ProgressView(value: rowStatus.progressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(rowStatus.statusAppearance.color)
                    .frame(height: IPadFileRowStyle.Metrics.progressBarHeight)
                    .transition(IPadFileRowStyle.progressTransition)
            }
        }
        .padding(.horizontal, IPadFileRowStyle.Metrics.rowHorizontalPadding)
        .padding(.vertical, IPadFileRowStyle.Metrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IPadFileRowBackground())
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: rowStatus.showsProgressBar)
    }
}
#endif
