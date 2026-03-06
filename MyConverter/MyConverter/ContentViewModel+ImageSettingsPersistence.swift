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

    func savePersistedImageSettings() {
        schedulePersistedSourceSettingsSave(using: imageSettingsDescriptor())
    }

    func loadPersistedImageSettings() -> [String: ImageConversionSettings] {
        loadPersistedSourceSettings(using: imageSettingsDescriptor())
    }
}
