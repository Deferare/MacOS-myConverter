import SwiftUI

extension ContentViewModel.MediaKind {
    private static let liquidGlassTintByKind: [Self: Color] = [
        .video: .blue,
        .image: .orange,
        .audio: .teal
    ]

    var liquidGlassTint: Color {
        Self.liquidGlassTintByKind[self] ?? .blue
    }
}
