import Foundation

extension ContentViewModel {
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

    func savePersistedAudioSettings() {
        scheduleDebouncedTask(\.pendingAudioSettingsSaveTask) { viewModel in
            viewModel.flushPersistedAudioSettings()
        }
    }

    private func flushPersistedAudioSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: audioSettingsBySourceID,
            mapToPersisted: { PersistedAudioConversionSettings(from: $0) },
            storageKey: audioSettingsStorageKey,
            failureContext: "Failed to persist audio settings"
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
