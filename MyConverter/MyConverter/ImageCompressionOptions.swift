import Foundation

enum ImageQualityOption: String, CaseIterable, Identifiable {
    case best = "Best (100%)"
    case high = "High (90%)"
    case medium = "Medium (75%)"
    case low = "Low (60%)"

    nonisolated var id: String { rawValue }

    nonisolated var compressionQuality: Double {
        Double(parsedParenthesizedInteger(in: rawValue) ?? 100) / 100.0
    }

    nonisolated var percent: Int {
        Int((compressionQuality * 100).rounded())
    }

    nonisolated static func ffmpegQScale(fromPercent percent: Int) -> Int {
        let clamped = max(1, min(percent, 100))
        return max(2, min(31, 32 - Int((Double(clamped) / 100.0) * 30.0)))
    }

    nonisolated static func ffmpegCRF(fromPercent percent: Int) -> Int {
        let clamped = max(1, min(percent, 100))
        return max(0, min(50, 51 - Int((Double(clamped) / 100.0) * 50.0)))
    }
}

enum PNGCompressionLevelOption: String, CaseIterable, Identifiable {
    case fastest = "Fastest (1)"
    case balanced = "Balanced (6)"
    case smallest = "Smallest File (9)"

    nonisolated var id: String { rawValue }

    nonisolated var level: Int {
        parsedParenthesizedInteger(in: rawValue) ?? 6
    }
}
