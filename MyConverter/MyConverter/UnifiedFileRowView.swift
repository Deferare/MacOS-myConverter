import AppKit
import SwiftUI

struct UnifiedFileRowView: View, Equatable {
    private enum Metrics {
        static let rowSpacing: CGFloat = 10
        static let rowHorizontalPadding: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 12
        static let leadingSectionSpacing: CGFloat = 12
        static let titleSpacing: CGFloat = 6
        static let outputSectionSpacing: CGFloat = 8
        static let statusIndicatorWidth: CGFloat = 36
        static let completionAccessoryOffset: CGFloat = 12
        static let completionAccessoryRevealDelayNanoseconds: UInt64 = 180_000_000
        static let visibilityTransitionAnimation = Animation.spring(response: 0.24, dampingFraction: 0.86)
        static let progressAnimationDuration: Double = 0.12
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
    let systemImage: String
    let rowState: RowState
    @State private var displayedCompletedOutputURL: URL?
    @State private var completionAccessoryRevealTask: Task<Void, Never>?

    init(
        sourceURL: URL,
        order: Int,
        systemImage: String,
        rowState: RowState
    ) {
        self.sourceURL = sourceURL
        self.order = order
        self.systemImage = systemImage
        self.rowState = rowState
        _displayedCompletedOutputURL = State(initialValue: rowState.completedOutputURL)
        _completionAccessoryRevealTask = State(initialValue: nil)
    }

    static func == (lhs: UnifiedFileRowView, rhs: UnifiedFileRowView) -> Bool {
        lhs.sourceURL == rhs.sourceURL &&
        lhs.order == rhs.order &&
        lhs.systemImage == rhs.systemImage &&
        lhs.rowState == rhs.rowState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            HStack(spacing: 0) {
                sourceSection
                outputSection
                statusIndicator
            }

            if rowState.showsProgressBar {
                ProgressView(value: rowState.progressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(rowState.statusAppearance.color)
                    .animation(progressAnimation, value: rowState.progressValue)
                    .transition(progressTransition)
            }
        }
        .padding(.horizontal, Metrics.rowHorizontalPadding)
        .padding(.vertical, Metrics.rowVerticalPadding)
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
        HStack(spacing: Metrics.leadingSectionSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: Metrics.titleSpacing) {
                Text("\(order)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)

                Text(sourceURL.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        Image(systemName: rowState.statusAppearance.symbolName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(rowState.statusAppearance.color)
            .frame(width: Metrics.statusIndicatorWidth)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        HStack(spacing: Metrics.outputSectionSpacing) {
            extensionBadgeView

            if let outputURL = displayedCompletedOutputURL {
                completedActionsView(outputURL)
                    .transition(completedActionsTransition)
            } else if case .skipped = rowState {
                statusPlaceholderView("Skipped", color: .orange)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private var extensionBadgeView: some View {
        Text(sourceURL.pathExtension.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.primary.opacity(0.04)))
            .fixedSize(horizontal: true, vertical: false)
    }

    private func completedActionsView(_ url: URL) -> some View {
        HStack(spacing: Metrics.outputSectionSpacing) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
            .fixedSize(horizontal: true, vertical: false)

            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Text("Open")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func statusPlaceholderView(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
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
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    private var rowFillColor: Color {
        Color.primary.opacity(0.015)
    }

    private var rowBorderColor: Color {
        Color.primary.opacity(0.06)
    }
}
