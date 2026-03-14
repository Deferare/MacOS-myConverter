import SwiftUI

struct UnifiedFileRowView: View, Equatable {
    fileprivate enum Metrics {
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

    let sourceURL: URL
    let order: Int
    let rowStatus: ContentViewModel.SelectedFileListState.RowStatus
    @State private var displayedCompletedOutputURL: URL?
    @State private var completionAccessoryRevealTask: Task<Void, Never>?

    init(
        sourceURL: URL,
        order: Int,
        rowStatus: ContentViewModel.SelectedFileListState.RowStatus
    ) {
        self.sourceURL = sourceURL
        self.order = order
        self.rowStatus = rowStatus
        _displayedCompletedOutputURL = State(initialValue: rowStatus.completedOutputURL)
        _completionAccessoryRevealTask = State(initialValue: nil)
    }

    static func == (lhs: UnifiedFileRowView, rhs: UnifiedFileRowView) -> Bool {
        lhs.sourceURL == rhs.sourceURL &&
            lhs.order == rhs.order &&
            lhs.rowStatus == rhs.rowStatus
    }

    static func estimatedHeight(for rowStatus: ContentViewModel.SelectedFileListState.RowStatus) -> CGFloat {
        let baseHeight = primaryContentMinHeight(for: rowStatus) + (Metrics.rowVerticalPadding * 2)
        guard rowStatus.showsProgressBar else {
            return baseHeight
        }

        return baseHeight + Metrics.rowSpacing + Metrics.progressBarHeight
    }

    private static func primaryContentMinHeight(
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

    private var primaryContentMinHeight: CGFloat {
        Self.primaryContentMinHeight(for: rowStatus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            HStack(spacing: 0) {
                sourceSection
                outputSection
                statusIndicator
            }
            .frame(minHeight: primaryContentMinHeight)

            if rowStatus.showsProgressBar {
                ProgressView(value: rowStatus.progressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(rowStatus.statusAppearance.color)
                    .frame(height: Metrics.progressBarHeight)
                    .animation(progressAnimation, value: rowStatus.progressValue)
                    .transition(progressTransition)
            }
        }
        .padding(.horizontal, Metrics.rowHorizontalPadding)
        .padding(.vertical, Metrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .animation(visibilityTransitionAnimation, value: rowStatus.showsProgressBar)
        .animation(visibilityTransitionAnimation, value: showsCompletedActions)
        .onDisappear {
            cancelCompletionAccessoryReveal()
        }
        .onChange(of: rowStatus) { oldValue, newValue in
            syncCompletedActions(from: oldValue, to: newValue)
        }
    }

    private var visibilityTransitionAnimation: Animation {
        Metrics.visibilityTransitionAnimation
    }

    private var progressTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        )
    }

    private var progressAnimation: Animation? {
        switch rowStatus {
        case .converting:
            return .linear(duration: Metrics.progressAnimationDuration)
        case .pending, .completed, .skipped:
            return nil
        }
    }

    private var completedActionsTransition: AnyTransition {
        .offset(x: Metrics.completionAccessoryOffset)
    }

    private var showsCompletedActions: Bool {
        displayedCompletedOutputURL != nil
    }

    private var decorativeGlass: Glass {
        Glass.regular.interactive(false)
    }

    private var actionLabelColor: Color {
        .white.opacity(0.82)
    }

    private var actionButtonFillColor: Color {
        .white.opacity(0.08)
    }

    private var actionButtonBorderColor: Color {
        .white.opacity(0.06)
    }

    private func cancelCompletionAccessoryReveal() {
        completionAccessoryRevealTask?.cancel()
        completionAccessoryRevealTask = nil
    }

    private func showCompletedActionsImmediately(for outputURL: URL) {
        cancelCompletionAccessoryReveal()
        displayedCompletedOutputURL = outputURL
    }

    private func scheduleCompletedActionsReveal(for outputURL: URL) {
        displayedCompletedOutputURL = nil
        completionAccessoryRevealTask = Task { @MainActor in
            defer {
                completionAccessoryRevealTask = nil
            }

            try? await Task.sleep(nanoseconds: Metrics.completionAccessoryRevealDelayNanoseconds)
            guard !Task.isCancelled else { return }
            guard rowStatus.completedOutputURL == outputURL else { return }

            withAnimation(visibilityTransitionAnimation) {
                displayedCompletedOutputURL = outputURL
            }
        }
    }

    private func syncCompletedActions(
        from previousState: ContentViewModel.SelectedFileListState.RowStatus,
        to newState: ContentViewModel.SelectedFileListState.RowStatus
    ) {
        cancelCompletionAccessoryReveal()

        if let outputURL = newState.completedOutputURL {
            guard previousState.showsProgressBar else {
                showCompletedActionsImmediately(for: outputURL)
                return
            }

            scheduleCompletedActionsReveal(for: outputURL)
            return
        }

        displayedCompletedOutputURL = nil
    }

    // MARK: - Source Section

    private var sourceSection: some View {
        HStack(spacing: Metrics.titleSpacing) {
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
                size: CGSize(width: Metrics.thumbnailWidth, height: Metrics.thumbnailHeight),
                cornerRadius: Metrics.thumbnailCornerRadius,
                borderOpacity: Metrics.thumbnailBorderOpacity
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

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        Image(systemName: rowStatus.statusAppearance.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(rowStatus.statusAppearance.color)
            .frame(width: Metrics.statusIndicatorWidth)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        HStack(spacing: Metrics.outputSectionSpacing) {
            if let outputURL = displayedCompletedOutputURL {
                UnifiedFileRowCompletedActionsView(
                    url: outputURL,
                    spacing: Metrics.outputSectionSpacing,
                    buttonHeight: Metrics.completedActionHeight,
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
            return Metrics.outputSectionSpacing
        case .pending, .converting:
            return 0
        }
    }

    // MARK: - Background

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(rowFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(rowBorderColor, lineWidth: 1)
            )
    }

    private var rowFillColor: Color {
        .white.opacity(0.06)
    }

    private var rowBorderColor: Color {
        .white.opacity(0.10)
    }
}
