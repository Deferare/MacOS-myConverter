import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageContainerOption: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case heic = "HEIC"
    case gif = "GIF"
    case jpeg2000 = "JPEG 2000"
    case tiff = "TIFF"
    case bmp = "BMP"

    nonisolated var id: String { rawValue }

    nonisolated var fileExtension: String {
        switch self {
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        case .heic:
            return "heic"
        case .gif:
            return "gif"
        case .jpeg2000:
            return "jp2"
        case .tiff:
            return "tiff"
        case .bmp:
            return "bmp"
        }
    }

    nonisolated var utType: UTType {
        switch self {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        case .heic:
            return .heic
        case .gif:
            return .gif
        case .jpeg2000:
            return UTType(importedAs: "public.jpeg-2000")
        case .tiff:
            return .tiff
        case .bmp:
            return .bmp
        }
    }

    nonisolated var supportsCompressionQuality: Bool {
        switch self {
        case .jpeg, .heic, .jpeg2000:
            return true
        case .png, .gif, .tiff, .bmp:
            return false
        }
    }

    nonisolated static var systemSupportedCases: [ImageContainerOption] {
        let destinationTypes = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        let supported = allCases.filter { destinationTypes.contains($0.utType.identifier) }
        return supported.isEmpty ? allCases : supported
    }
}

enum ImageQualityOption: String, CaseIterable, Identifiable {
    case best = "Best (100%)"
    case high = "High (90%)"
    case medium = "Medium (75%)"
    case low = "Low (60%)"

    nonisolated var id: String { rawValue }

    nonisolated var compressionQuality: Double {
        switch self {
        case .best:
            return 1.0
        case .high:
            return 0.9
        case .medium:
            return 0.75
        case .low:
            return 0.6
        }
    }
}
