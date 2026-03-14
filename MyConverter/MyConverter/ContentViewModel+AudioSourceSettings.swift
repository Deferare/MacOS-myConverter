import Foundation

extension ContentViewModel {
    func currentAudioSourceSettings() -> AudioConversionSettings {
        let audioSettings = Self.storedAudioEncodingSettings(
            from: audioOutputEncodingSelectionState
        )
        return AudioConversionSettings(
            outputFormatID: audioOptionsState.selectedOutputFormat.id,
            audioEncoder: audioSettings.encoder,
            audioMode: audioSettings.mode,
            sampleRate: audioSettings.sampleRate,
            audioBitRate: audioSettings.bitRate
        )
    }

    func applyAudioSourceSettings(_ settings: AudioConversionSettings) {
        applyStoredOutputFormatSettings(
            using: Self.audioOutputFormatDescriptor,
            applyingFlagKeyPath: \.settingsState.isApplyingAudioSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            applyAdditionalSettings: {
                Self.applyStoredAudioEncodingSettings(
                    StoredAudioEncodingSettings(
                        encoder: settings.audioEncoder,
                        mode: settings.audioMode,
                        sampleRate: settings.sampleRate,
                        bitRate: settings.audioBitRate
                    ),
                    to: self,
                    encoder: \.audioOptionsState.selectedOutputEncoder,
                    mode: \.audioOptionsState.selectedOutputMode,
                    sampleRate: \.audioOptionsState.selectedOutputSampleRate,
                    bitRate: \.audioOptionsState.selectedOutputBitRate
                )
            },
            postApply: {
                ensureSelectedOutputFormatIsAvailable(using: Self.audioOutputFormatDescriptor)
                MediaKind.audio.refreshCodecOptions(in: self)
            }
        )
    }

    func applyStoredAudioSourceSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: settingsState.audioSettingsBySourceID,
            defaultSettings: AudioConversionSettings(),
            apply: { self.applyAudioSourceSettings($0) }
        )
    }

    func persistCurrentAudioSourceSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: settingsState.isApplyingAudioSettings,
            sourceURL: audioRuntimeState.media.sourceURL,
            settingsKeyPath: \.settingsState.audioSettingsBySourceID,
            buildSettings: { currentAudioSourceSettings() },
            savePersistedSettings: { schedulePersistedAudioSourceSettingsSave() }
        )
    }

    func schedulePersistedAudioSourceSettingsSave() {
        schedulePersistedSourceSettingsSave(
            \.taskState.pendingAudioSettingsSaveTask,
            settingsKeyPath: \.settingsState.audioSettingsBySourceID,
            mapToPersisted: { PersistedAudioConversionSettings(from: $0) },
            storageKey: Self.audioSourceSettingsStorageKey,
            failureContext: MediaKind.audio.saveSettingsFailureContext
        )
    }
}
