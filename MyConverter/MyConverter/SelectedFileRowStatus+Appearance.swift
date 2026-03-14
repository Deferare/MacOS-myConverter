import Foundation
import SwiftUI

struct SelectedFileRowStatusAppearance {
    let symbolName: String
    let color: Color
}

extension ContentViewModel.SelectedFileListState.RowStatus {
    private enum Kind: Hashable {
        case pending
        case converting
        case completed
        case skipped

        private static let appearanceByKind: [Self: SelectedFileRowStatusAppearance] = [
            .pending: SelectedFileRowStatusAppearance(
                symbolName: "circle.dashed",
                color: .secondary.opacity(0.45)
            ),
            .converting: SelectedFileRowStatusAppearance(
                symbolName: "circle.fill",
                color: .accentColor
            ),
            .completed: SelectedFileRowStatusAppearance(
                symbolName: "checkmark.circle.fill",
                color: .green
            ),
            .skipped: SelectedFileRowStatusAppearance(
                symbolName: "exclamationmark.triangle.fill",
                color: .orange
            )
        ]

        private static let progressByKind: [Self: Double] = [
            .pending: 0,
            .completed: 1,
            .skipped: 1
        ]

        var appearance: SelectedFileRowStatusAppearance {
            Self.appearanceByKind[self] ?? Self.appearanceByKind[.pending]!
        }

        var defaultProgressValue: Double {
            Self.progressByKind[self] ?? 0
        }
    }

    private var kind: Kind {
        switch self {
        case .pending:
            .pending
        case .converting:
            .converting
        case .completed:
            .completed
        case .skipped:
            .skipped
        }
    }

    var showsProgressBar: Bool {
        kind == .converting
    }

    var progressValue: Double {
        if case .converting(let progress) = self {
            return progress
        }

        return kind.defaultProgressValue
    }

    var completedOutputURL: URL? {
        guard case .completed(let outputURL) = self else {
            return nil
        }

        return outputURL
    }

    var statusAppearance: SelectedFileRowStatusAppearance {
        kind.appearance
    }
}
