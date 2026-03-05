import Foundation

extension ContentViewModel {
    func applyStoredImageSettings(_ settings: ImageConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredImageSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            options: imageOutputFormatOptions,
            selectedFormatKeyPath: \.selectedImageOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedImageResolution = settings.resolution
                selectedImageQuality = settings.quality
                selectedPNGCompressionLevel = settings.pngCompressionLevel
                preserveImageAnimation = settings.preserveAnimation
            },
            postApply: {
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    func ensureSelectedImageOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: imageOutputFormatOptions,
            selectedFormatKeyPath: \.selectedImageOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: { $0.first }
        )
    }
}
