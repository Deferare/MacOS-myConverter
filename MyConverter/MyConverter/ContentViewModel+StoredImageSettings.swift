import Foundation

extension ContentViewModel {
    func applyStoredImageSettings(_ settings: ImageConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.settingsState.isApplyingImageSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            formatDescriptor: imageOutputFormatDescriptor(),
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
        ensureSelectedOutputFormatIsAvailable(using: imageOutputFormatDescriptor())
    }
}
