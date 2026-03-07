import AppKit
import SwiftUI

struct UnifiedFileRowView: View, Equatable {
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

        var progressTint: Color {
            switch self {
            case .pending:
                return .secondary.opacity(0.45)
            case .converting:
                return .accentColor
            case .completed:
                return .green
            case .skipped:
                return .orange
            }
        }

        var symbolName: String {
            switch self {
            case .pending:
                return "circle.dashed"
            case .converting:
                return "circle.fill"
            case .completed:
                return "checkmark.circle.fill"
            case .skipped:
                return "exclamationmark.triangle.fill"
            }
        }

        var symbolColor: Color {
            switch self {
            case .pending:
                return .secondary.opacity(0.45)
            case .converting:
                return .accentColor
            case .completed:
                return .green
            case .skipped:
                return .orange
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
        _displayedCompletedOutputURL = State(initialValue: Self.initialCompletedOutputURL(for: rowState))
        _completionAccessoryRevealTask = State(initialValue: nil)
    }

    static func == (lhs: UnifiedFileRowView, rhs: UnifiedFileRowView) -> Bool {
        lhs.sourceURL == rhs.sourceURL &&
        lhs.order == rhs.order &&
        lhs.systemImage == rhs.systemImage &&
        lhs.rowState == rhs.rowState
    }

    private static func initialCompletedOutputURL(for rowState: RowState) -> URL? {
        guard case .completed(let outputURL) = rowState else {
            return nil
        }

        return outputURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                sourceSection
                outputSection
                statusIndicator
            }

            if rowState.showsProgressBar {
                ProgressView(value: rowState.progressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(rowState.progressTint)
                    .animation(progressAnimation, value: rowState.progressValue)
                    .transition(progressTransition)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackground)
        .animation(visibilityTransitionAnimation, value: rowState.showsProgressBar)
        .animation(visibilityTransitionAnimation, value: displayedCompletedOutputURL != nil)
        .onDisappear {
            completionAccessoryRevealTask?.cancel()
        }
        .onChange(of: rowState) { oldValue, newValue in
            syncCompletedActions(from: oldValue, to: newValue)
        }
    }

    private var visibilityTransitionAnimation: Animation {
        .spring(response: 0.24, dampingFraction: 0.86)
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
            return .linear(duration: 0.12)
        case .pending, .completed, .skipped:
            return nil
        }
    }

    private var completedActionsTransition: AnyTransition {
        .offset(x: 12)
    }

    private func syncCompletedActions(from previousState: RowState, to newState: RowState) {
        completionAccessoryRevealTask?.cancel()

        switch newState {
        case .completed(let outputURL):
            guard previousState.showsProgressBar else {
                displayedCompletedOutputURL = outputURL
                return
            }

            displayedCompletedOutputURL = nil
            completionAccessoryRevealTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                guard case .completed(let currentURL) = rowState, currentURL == outputURL else { return }

                withAnimation(visibilityTransitionAnimation) {
                    displayedCompletedOutputURL = outputURL
                }
            }

        case .pending, .converting, .skipped:
            displayedCompletedOutputURL = nil
        }
    }

    // MARK: - Source Section

    private var sourceSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 6) {
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
        Image(systemName: rowState.symbolName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(rowState.symbolColor)
        .frame(width: 36)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        HStack(spacing: 8) {
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
        HStack(spacing: 8) {
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
