import Foundation

extension ContentViewModel {
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

    func savePersistedSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: videoSettingsBySourceID,
            mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
            storageKey: videoSettingsStorageKey,
            failureContext: "Failed to persist video settings"
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
}
