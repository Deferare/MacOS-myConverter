import AppKit
import SwiftUI

struct UnifiedFileRowView: View, Equatable {
    private enum Metrics {
        static let rowSpacing: CGFloat = 10
        static let rowHorizontalPadding: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 12
        static let progressBarHeight: CGFloat = 6
        static let titleSpacing: CGFloat = 6
        static let outputSectionSpacing: CGFloat = 8
        static let primaryContentMinHeight: CGFloat = 26
        static let completedActionHeight: CGFloat = 30
        static let statusIndicatorWidth: CGFloat = 36
        static let completionAccessoryOffset: CGFloat = 12
        static let completionAccessoryRevealDelayNanoseconds: UInt64 = 180_000_000
        static let visibilityTransitionAnimation = Animation.spring(response: 0.24, dampingFraction: 0.86)
        static let progressAnimationDuration: Double = 0.06
    }

    struct StatusAppearance {
        let symbolName: String
        let color: Color
    }

    enum RowState: Equatable {
        case pending
        case converting(progress: Double)
        case completed(URL)
        case skipped

        var showsProgressBar: Bool {
            switch self {
            case .converting:
                return true
            case .pending, .completed, .skipped:
                return false
            }
        }

        var progressValue: Double {
            switch self {
            case .pending:
                return 0
            case .converting(let progress):
                return progress
            case .completed:
                return 1
            case .skipped:
                return 1
            }
        }

        var completedOutputURL: URL? {
            guard case .completed(let outputURL) = self else {
                return nil
            }

            return outputURL
        }

        var statusAppearance: StatusAppearance {
            switch self {
            case .pending:
                return StatusAppearance(
                    symbolName: "circle.dashed",
                    color: .secondary.opacity(0.45)
                )
            case .converting:
                return StatusAppearance(
                    symbolName: "circle.fill",
                    color: .accentColor
                )
            case .completed:
                return StatusAppearance(
                    symbolName: "checkmark.circle.fill",
                    color: .green
                )
            case .skipped:
                return StatusAppearance(
                    symbolName: "exclamationmark.triangle.fill",
                    color: .orange
                )
            }
        }
    }

    let sourceURL: URL
    let order: Int
    let rowState: RowState
    @State private var displayedCompletedOutputURL: URL?
    @State private var completionAccessoryRevealTask: Task<Void, Never>?

    init(
        sourceURL: URL,
        order: Int,
        rowState: RowState
    ) {
        self.sourceURL = sourceURL
        self.order = order
        self.rowState = rowState
        _displayedCompletedOutputURL = State(initialValue: rowState.completedOutputURL)
        _completionAccessoryRevealTask = State(initialValue: nil)
    }

    static func == (lhs: UnifiedFileRowView, rhs: UnifiedFileRowView) -> Bool {
        lhs.sourceURL == rhs.sourceURL &&
        lhs.order == rhs.order &&
        lhs.rowState == rhs.rowState
    }

    static func estimatedHeight(for rowState: RowState) -> CGFloat {
        let baseHeight = primaryContentMinHeight(for: rowState) + (Metrics.rowVerticalPadding * 2)
        guard rowState.showsProgressBar else {
            return baseHeight
        }

        return baseHeight + Metrics.rowSpacing + Metrics.progressBarHeight
    }

    private static func primaryContentMinHeight(for rowState: RowState) -> CGFloat {
        switch rowState {
        case .completed:
            return max(Metrics.primaryContentMinHeight, Metrics.completedActionHeight)
        case .pending, .converting, .skipped:
            return Metrics.primaryContentMinHeight
        }
    }

    private var primaryContentMinHeight: CGFloat {
        Self.primaryContentMinHeight(for: rowState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            HStack(spacing: 0) {
                sourceSection
                outputSection
                statusIndicator
            }
            .frame(minHeight: primaryContentMinHeight)

            if rowState.showsProgressBar {
                ProgressView(value: rowState.progressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(rowState.statusAppearance.color)
                    .frame(height: Metrics.progressBarHeight)
                    .animation(progressAnimation, value: rowState.progressValue)
                    .transition(progressTransition)
            }
        }
        .padding(.horizontal, Metrics.rowHorizontalPadding)
        .padding(.vertical, Metrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .animation(visibilityTransitionAnimation, value: rowState.showsProgressBar)
        .animation(visibilityTransitionAnimation, value: showsCompletedActions)
        .onDisappear {
            cancelCompletionAccessoryReveal()
        }
        .onChange(of: rowState) { oldValue, newValue in
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
        switch rowState {
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

    private func statusGlass(_ color: Color) -> Glass {
        Glass.regular.tint(color).interactive(false)
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
            guard rowState.completedOutputURL == outputURL else { return }

            withAnimation(visibilityTransitionAnimation) {
                displayedCompletedOutputURL = outputURL
            }
        }
    }

    private func syncCompletedActions(from previousState: RowState, to newState: RowState) {
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
        Image(systemName: rowState.statusAppearance.symbolName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(rowState.statusAppearance.color)
            .frame(width: Metrics.statusIndicatorWidth)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        HStack(spacing: Metrics.outputSectionSpacing) {
            if let outputURL = displayedCompletedOutputURL {
                completedActionsView(outputURL)
                    .transition(completedActionsTransition)
            } else if case .skipped = rowState {
                statusPlaceholderView("Skipped", color: .orange)
            }
        }
        .padding(.leading, outputSectionLeadingPadding)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private var outputSectionLeadingPadding: CGFloat {
        switch rowState {
        case .completed, .skipped:
            return Metrics.outputSectionSpacing
        case .pending, .converting:
            return 0
        }
    }

    private func completedActionsView(_ url: URL) -> some View {
        HStack(spacing: Metrics.outputSectionSpacing) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Label("Show in Finder", systemImage: "folder")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(actionLabelColor)
                    .frame(width: 38, height: Metrics.completedActionHeight)
                    .background(actionButtonBackground)
            }
            .buttonStyle(HoverScaleButtonStyle())
            .help("Show in Finder")

            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Text("Open")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(actionLabelColor)
                    .padding(.horizontal, 18)
                    .frame(height: Metrics.completedActionHeight)
                    .background(actionButtonBackground)
            }
            .buttonStyle(HoverScaleButtonStyle())
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var actionButtonBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(actionButtonFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(actionButtonBorderColor, lineWidth: 1)
            )
    }

    private func statusPlaceholderView(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(statusGlass(color), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
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

private struct HoverScaleButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : (isHovered ? 1.04 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation {
                    isHovered = hovering
                }
            }
    }
}
