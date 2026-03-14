import Foundation

extension ContentViewModel {
    func currentImageSourceSettings() -> ImageConversionSettings {
        ImageConversionSettings(
            outputFormatID: imageOptionsState.selectedOutputFormat.id,
            resolution: imageOptionsState.selectedResolution,
            quality: imageOptionsState.selectedQuality,
            pngCompressionLevel: imageOptionsState.selectedPNGCompressionLevel,
            preserveAnimation: imageOptionsState.preserveAnimation
        )
    }

    func applyImageSourceSettings(_ settings: ImageConversionSettings) {
        applyStoredOutputFormatSettings(
            using: Self.imageOutputFormatDescriptor,
            applyingFlagKeyPath: \.settingsState.isApplyingImageSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            applyAdditionalSettings: {
                imageOptionsState.selectedResolution = settings.resolution
                imageOptionsState.selectedQuality = settings.quality
                imageOptionsState.selectedPNGCompressionLevel = settings.pngCompressionLevel
                imageOptionsState.preserveAnimation = settings.preserveAnimation
            },
            postApply: {
                ensureSelectedOutputFormatIsAvailable(using: Self.imageOutputFormatDescriptor)
            }
        )
    }

    func applyStoredImageSourceSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: settingsState.imageSettingsBySourceID,
            defaultSettings: ImageConversionSettings(),
            apply: { self.applyImageSourceSettings($0) }
        )
    }

    func persistCurrentImageSourceSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: settingsState.isApplyingImageSettings,
            sourceURL: imageRuntimeState.media.sourceURL,
            settingsKeyPath: \.settingsState.imageSettingsBySourceID,
            buildSettings: { currentImageSourceSettings() },
            savePersistedSettings: { schedulePersistedImageSourceSettingsSave() }
        )
    }

    func schedulePersistedImageSourceSettingsSave() {
        schedulePersistedSourceSettingsSave(
            \.taskState.pendingImageSettingsSaveTask,
            settingsKeyPath: \.settingsState.imageSettingsBySourceID,
            mapToPersisted: { PersistedImageConversionSettings(from: $0) },
            storageKey: Self.imageSourceSettingsStorageKey,
            failureContext: MediaKind.image.saveSettingsFailureContext
        )
    }
}
