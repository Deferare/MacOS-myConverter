import Foundation

extension ContentViewModel {
    func persistCurrentImageSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(using: imageSettingsDescriptor()) {
            ImageConversionSettings(
                outputFormatID: selectedImageOutputFormat.id,
                resolution: selectedImageResolution,
                quality: selectedImageQuality,
                pngCompressionLevel: selectedPNGCompressionLevel,
                preserveAnimation: preserveImageAnimation
            )
        }
    }
}
