import Foundation

extension ContentViewModel {
    func persistCurrentImageSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: isApplyingStoredImageSettings,
            sourceURL: imageSourceURL,
            settingsKeyPath: \.imageSettingsBySourceID,
            buildSettings: {
                ImageConversionSettings(
                    outputFormatID: selectedImageOutputFormat.id,
                    resolution: selectedImageResolution,
                    quality: selectedImageQuality,
                    pngCompressionLevel: selectedPNGCompressionLevel,
                    preserveAnimation: preserveImageAnimation
                )
            },
            savePersistedSettings: savePersistedImageSettings
        )
    }

    func savePersistedImageSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: imageSettingsBySourceID,
            mapToPersisted: { PersistedImageConversionSettings(from: $0) },
            storageKey: imageSettingsStorageKey,
            failureContext: "Failed to persist image settings"
        )
    }

    func loadPersistedImageSettings() -> [String: ImageConversionSettings] {
        loadPersistedSourceSettings(
            [String: PersistedImageConversionSettings].self,
            storageKey: imageSettingsStorageKey,
            failureContext: "Failed to load persisted image settings",
            restore: { $0.restoredSettings }
        )
    }
}
