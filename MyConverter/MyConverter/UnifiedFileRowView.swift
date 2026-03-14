import SwiftUI

struct UnifiedFileRowView: View, Equatable {
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
        UnifiedFileRowStyle.estimatedHeight(for: rowStatus)
    }

    private var primaryContentMinHeight: CGFloat {
        UnifiedFileRowStyle.primaryContentMinHeight(for: rowStatus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UnifiedFileRowStyle.Metrics.rowSpacing) {
            HStack(spacing: 0) {
                UnifiedFileRowSourceSection(
                    sourceURL: sourceURL,
                    order: order,
                    decorativeGlass: decorativeGlass
                )
                UnifiedFileRowOutputSection(
                    rowStatus: rowStatus,
                    displayedCompletedOutputURL: displayedCompletedOutputURL,
                    completedActionsTransition: completedActionsTransition,
                    actionLabelColor: actionLabelColor,
                    actionButtonFillColor: actionButtonFillColor,
                    actionButtonBorderColor: actionButtonBorderColor
                )
                UnifiedFileRowStatusIndicator(rowStatus: rowStatus)
            }
            .frame(minHeight: primaryContentMinHeight)

            if rowStatus.showsProgressBar {
                ProgressView(value: rowStatus.progressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(rowStatus.statusAppearance.color)
                    .frame(height: UnifiedFileRowStyle.Metrics.progressBarHeight)
                    .animation(progressAnimation, value: rowStatus.progressValue)
                    .transition(progressTransition)
            }
        }
        .padding(.horizontal, UnifiedFileRowStyle.Metrics.rowHorizontalPadding)
        .padding(.vertical, UnifiedFileRowStyle.Metrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UnifiedFileRowBackground())
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
        UnifiedFileRowStyle.Metrics.visibilityTransitionAnimation
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
            return .linear(duration: UnifiedFileRowStyle.Metrics.progressAnimationDuration)
        case .pending, .completed, .skipped:
            return nil
        }
    }

    private var completedActionsTransition: AnyTransition {
        .offset(x: UnifiedFileRowStyle.Metrics.completionAccessoryOffset)
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

            try? await Task.sleep(
                nanoseconds: UnifiedFileRowStyle.Metrics.completionAccessoryRevealDelayNanoseconds
            )
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
}
