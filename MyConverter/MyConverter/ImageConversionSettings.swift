import Foundation

struct ImageConversionSettings: Equatable {
    var outputFormatID: String = "public.png"
    var resolution: ResolutionOption = .original
    var quality: ImageQualityOption = .high
    var pngCompressionLevel: PNGCompressionLevelOption = .balanced
    var preserveAnimation: Bool = true
}

struct PersistedImageConversionSettings: Codable {
    var outputFormat: String
    var resolution: String
    var quality: String
    var pngCompressionLevel: String
    var preserveAnimation: Bool

    private enum CodingKeys: String, CodingKey {
        case outputFormat
        case resolution
        case quality
        case pngCompressionLevel
        case preserveAnimation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputFormat = try container.decodeRequiredString(forKey: .outputFormat)
        resolution = try container.decodeRequiredString(forKey: .resolution)
        quality = try container.decodeRequiredString(forKey: .quality)
        pngCompressionLevel = try container.decodeString(
            forKey: .pngCompressionLevel,
            default: PNGCompressionLevelOption.balanced.rawValue
        )
        preserveAnimation = try container.decodeBool(forKey: .preserveAnimation, default: true)
    }

    init(from settings: ImageConversionSettings) {
        outputFormat = settings.outputFormatID
        resolution = settings.resolution.rawValue
        quality = settings.quality.rawValue
        pngCompressionLevel = settings.pngCompressionLevel.rawValue
        preserveAnimation = settings.preserveAnimation
    }

    var restoredSettings: ImageConversionSettings {
        ImageConversionSettings(
            outputFormatID: outputFormat,
            resolution: restoredOption(resolution, default: .original),
            quality: restoredOption(quality, default: .high),
            pngCompressionLevel: restoredOption(pngCompressionLevel, default: .balanced),
            preserveAnimation: preserveAnimation
        )
    }
}
