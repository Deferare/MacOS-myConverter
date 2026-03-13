import SwiftUI

extension ContentViewModel.ConversionStatusLevel {
    var color: Color {
        switch self {
        case .normal:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
