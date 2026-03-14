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

    func schedulePersistedVideoSourceSettingsSave() {
        schedulePersistedSourceSettingsSave(
            \.taskState.pendingVideoSettingsSaveTask,
            settingsKeyPath: \.settingsState.videoSettingsBySourceID,
            mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
            storageKey: Self.videoSourceSettingsStorageKey,
            failureContext: MediaKind.video.saveSettingsFailureContext
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

extension ContentViewModel.MediaKind {
    private struct SourceSettingsBehavior {
        let applyDefaultSourceSettings: (ContentViewModel) -> Void
        let applyStoredSourceSettings: (ContentViewModel, String) -> Void
        let persistCurrentSourceSettingsIfNeeded: (ContentViewModel) -> Void
    }

    private static let sourceSettingsBehaviorByKind: [Self: SourceSettingsBehavior] = [
        .video: SourceSettingsBehavior(
            applyDefaultSourceSettings: {
                $0.applyVideoSourceSettings(VideoConversionSettings())
            },
            applyStoredSourceSettings: { viewModel, sourceID in
                viewModel.applyStoredVideoSourceSettings(for: sourceID)
            },
            persistCurrentSourceSettingsIfNeeded: {
                $0.persistCurrentVideoSourceSettingsIfNeeded()
            }
        ),
        .image: SourceSettingsBehavior(
            applyDefaultSourceSettings: {
                $0.applyImageSourceSettings(ImageConversionSettings())
            },
            applyStoredSourceSettings: { viewModel, sourceID in
                viewModel.applyStoredImageSourceSettings(for: sourceID)
            },
            persistCurrentSourceSettingsIfNeeded: {
                $0.persistCurrentImageSourceSettingsIfNeeded()
            }
        ),
        .audio: SourceSettingsBehavior(
            applyDefaultSourceSettings: {
                $0.applyAudioSourceSettings(AudioConversionSettings())
            },
            applyStoredSourceSettings: { viewModel, sourceID in
                viewModel.applyStoredAudioSourceSettings(for: sourceID)
            },
            persistCurrentSourceSettingsIfNeeded: {
                $0.persistCurrentAudioSourceSettingsIfNeeded()
            }
        )
    ]

    private var sourceSettingsBehavior: SourceSettingsBehavior {
        Self.sourceSettingsBehaviorByKind[self] ?? Self.sourceSettingsBehaviorByKind[.video]!
    }

    func applyDefaultSourceSettings(to viewModel: ContentViewModel) {
        sourceSettingsBehavior.applyDefaultSourceSettings(viewModel)
    }

    func applyStoredSourceSettings(sourceID: String, to viewModel: ContentViewModel) {
        sourceSettingsBehavior.applyStoredSourceSettings(viewModel, sourceID)
    }

    func persistCurrentSourceSettingsIfNeeded(in viewModel: ContentViewModel) {
        sourceSettingsBehavior.persistCurrentSourceSettingsIfNeeded(viewModel)
    }
}
