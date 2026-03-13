import Foundation
import SwiftUI

struct SelectedFileRowStatusAppearance {
    let symbolName: String
    let color: Color
}

extension ContentViewModel.SelectedFileListState.RowStatus {
    var showsProgressBar: Bool {
        if case .converting = self {
            return true
        }

        return false
    }

    var progressValue: Double {
        switch self {
        case .pending:
            return 0
        case .converting(let progress):
            return progress
        case .completed, .skipped:
            return 1
        }
    }

    var completedOutputURL: URL? {
        guard case .completed(let outputURL) = self else {
            return nil
        }

        return outputURL
    }

    var statusAppearance: SelectedFileRowStatusAppearance {
        switch self {
        case .pending:
            return SelectedFileRowStatusAppearance(
                symbolName: "circle.dashed",
                color: .secondary.opacity(0.45)
            )
        case .converting:
            return SelectedFileRowStatusAppearance(
                symbolName: "circle.fill",
                color: .accentColor
            )
        case .completed:
            return SelectedFileRowStatusAppearance(
                symbolName: "checkmark.circle.fill",
                color: .green
            )
        case .skipped:
            return SelectedFileRowStatusAppearance(
                symbolName: "exclamationmark.triangle.fill",
                color: .orange
            )
        }
    }
}
