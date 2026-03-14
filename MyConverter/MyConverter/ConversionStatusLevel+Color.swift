import SwiftUI

extension ContentViewModel.ConversionStatusLevel: Hashable {}

extension ContentViewModel.ConversionStatusLevel {
    private static let colorByLevel: [Self: Color] = [
        .normal: .secondary,
        .warning: .orange,
        .error: .red
    ]

    var color: Color {
        Self.colorByLevel[self] ?? .secondary
    }
}
