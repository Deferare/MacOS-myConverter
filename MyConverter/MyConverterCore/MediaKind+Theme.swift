import SwiftUI

extension ContentViewModel.MediaKind {
    var liquidGlassTint: Color {
        switch self {
        case .video:
            return .blue
        case .image:
            return .orange
        case .audio:
            return .teal
        }
    }
}
