import Foundation

extension ContentViewModel {
    func scheduleVideoFormatChangeHandling() {
        scheduleDeferredTask(\.pendingVideoFormatChangeTask) { viewModel in
            viewModel.refreshVideoCodecOptions()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    func scheduleVideoOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.pendingVideoOptionNormalizationTask) { viewModel in
            viewModel.normalizeVideoOptionDependencies()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    func scheduleAudioFormatChangeHandling() {
        scheduleDeferredTask(\.pendingAudioFormatChangeTask) { viewModel in
            viewModel.refreshAudioCodecOptions()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    func scheduleAudioOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.pendingAudioOptionNormalizationTask) { viewModel in
            viewModel.normalizeAudioOptionDependencies()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    func persistCurrentSettingsIfNeeded() {
        persistCurrentVideoSettingsIfNeeded()
    }

    func persistCurrentVideoSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: isApplyingStoredSettings,
            sourceURL: sourceURL,
            settingsKeyPath: \.videoSettingsBySourceID,
            buildSettings: {
                VideoConversionSettings(
                    outputFormatID: selectedOutputFormat.id,
                    videoEncoder: selectedVideoEncoder,
                    resolution: selectedResolution,
                    frameRate: selectedFrameRate,
                    gifPlaybackSpeed: selectedGIFPlaybackSpeed,
                    videoBitRate: selectedVideoBitRate,
                    customVideoBitRate: customVideoBitRate,
                    audioEncoder: selectedAudioEncoder,
                    audioMode: selectedAudioMode,
                    sampleRate: selectedSampleRate,
                    audioBitRate: selectedAudioBitRate
                )
            },
            savePersistedSettings: savePersistedSettings
        )
    }

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

    func persistCurrentAudioSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: isApplyingStoredAudioSettings,
            sourceURL: audioSourceURL,
            settingsKeyPath: \.audioSettingsBySourceID,
            buildSettings: {
                AudioConversionSettings(
                    outputFormatID: selectedAudioOutputFormat.id,
                    audioEncoder: selectedAudioOutputEncoder,
                    audioMode: selectedAudioOutputMode,
                    sampleRate: selectedAudioOutputSampleRate,
                    audioBitRate: selectedAudioOutputBitRate
                )
            },
            savePersistedSettings: savePersistedAudioSettings
        )
    }

    func savePersistedSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: videoSettingsBySourceID,
            mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
            storageKey: videoSettingsStorageKey,
            failureContext: "Failed to persist video settings"
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

    func savePersistedAudioSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: audioSettingsBySourceID,
            mapToPersisted: { PersistedAudioConversionSettings(from: $0) },
            storageKey: audioSettingsStorageKey,
            failureContext: "Failed to persist audio settings"
        )
    }

    func loadPersistedSettings() -> [String: VideoConversionSettings] {
        loadPersistedSourceSettings(
            [String: PersistedVideoConversionSettings].self,
            storageKey: videoSettingsStorageKey,
            failureContext: "Failed to load persisted video settings",
            restore: { $0.restoredSettings }
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

    func loadPersistedAudioSettings() -> [String: AudioConversionSettings] {
        loadPersistedSourceSettings(
            [String: PersistedAudioConversionSettings].self,
            storageKey: audioSettingsStorageKey,
            failureContext: "Failed to load persisted audio settings",
            restore: { $0.restoredSettings }
        )
    }
}
