import Foundation

extension ContentViewModel {
    private static func videoConversionSettings(
        from selection: VideoEncodingSelectionState
    ) -> VideoConversionSettings {
        let audioSettings = storedAudioEncodingSettings(from: selection.audioSettings)
        return VideoConversionSettings(
            outputFormatID: selection.selectedOutputFormat.id,
            videoEncoder: selection.selectedVideoEncoder,
            resolution: selection.selectedResolution,
            frameRate: selection.selectedFrameRate,
            gifPlaybackSpeed: selection.selectedGIFPlaybackSpeed,
            videoBitRate: selection.selectedVideoBitRate,
            customVideoBitRate: selection.customVideoBitRate,
            audioEncoder: audioSettings.encoder,
            audioMode: audioSettings.mode,
            sampleRate: audioSettings.sampleRate,
            audioBitRate: audioSettings.bitRate
        )
    }

    private static func applyVideoConversionSettings(
        _ settings: VideoConversionSettings,
        to viewModel: ContentViewModel
    ) {
        viewModel.videoOptionsState.selectedVideoEncoder = settings.videoEncoder
        viewModel.videoOptionsState.selectedResolution = settings.resolution
        viewModel.videoOptionsState.selectedFrameRate = settings.frameRate
        viewModel.videoOptionsState.selectedGIFPlaybackSpeed = settings.gifPlaybackSpeed
        viewModel.videoOptionsState.selectedVideoBitRate = settings.videoBitRate
        viewModel.videoOptionsState.customVideoBitRate = settings.customVideoBitRate
        applyStoredAudioEncodingSettings(
            StoredAudioEncodingSettings(
                encoder: settings.audioEncoder,
                mode: settings.audioMode,
                sampleRate: settings.sampleRate,
                bitRate: settings.audioBitRate
            ),
            to: viewModel,
            encoder: \.videoOptionsState.selectedAudioEncoder,
            mode: \.videoOptionsState.selectedAudioMode,
            sampleRate: \.videoOptionsState.selectedSampleRate,
            bitRate: \.videoOptionsState.selectedAudioBitRate
        )
    }

    func currentVideoSourceSettings() -> VideoConversionSettings {
        Self.videoConversionSettings(from: videoEncodingSelectionState)
    }

    func applyVideoSourceSettings(_ settings: VideoConversionSettings) {
        applyStoredOutputFormatSettings(
            using: Self.videoOutputFormatDescriptor,
            applyingFlagKeyPath: \.settingsState.isApplyingVideoSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
            applyAdditionalSettings: {
                Self.applyVideoConversionSettings(settings, to: self)
            },
            postApply: {
                ensureSelectedOutputFormatIsAvailable(using: Self.videoOutputFormatDescriptor)
                MediaKind.video.refreshCodecOptions(in: self)
            }
        )
    }

    func applyStoredVideoSourceSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: settingsState.videoSettingsBySourceID,
            defaultSettings: VideoConversionSettings(),
            apply: { self.applyVideoSourceSettings($0) }
        )
    }

    func persistCurrentVideoSourceSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: settingsState.isApplyingVideoSettings,
            sourceURL: videoRuntimeState.media.sourceURL,
            settingsKeyPath: \.settingsState.videoSettingsBySourceID,
            buildSettings: { currentVideoSourceSettings() },
            savePersistedSettings: { schedulePersistedVideoSourceSettingsSave() }
        )
    }

    func schedulePersistedVideoSourceSettingsSave() {
        schedulePersistedSourceSettingsSave(
            \.taskState.pendingVideoSettingsSaveTask,
            settingsKeyPath: \.settingsState.videoSettingsBySourceID,
            mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
            storageKey: Self.videoSourceSettingsStorageKey,
            failureContext: MediaKind.video.saveSettingsFailureContext
        )
    }
}
