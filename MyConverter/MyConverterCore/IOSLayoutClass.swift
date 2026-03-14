import Foundation

enum IOSLayoutClass: Equatable {
    case compact
    case regular

    static func resolve(
        hasCompactWidth: Bool,
        availableWidth: CGFloat
    ) -> Self {
        if hasCompactWidth || availableWidth < 700 {
            return .compact
        }

        return .regular
    }
}
