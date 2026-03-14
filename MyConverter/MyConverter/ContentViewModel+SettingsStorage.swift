import Foundation

private let persistedSettingsSaveQueue = DispatchQueue(
    label: "myconverter.settings.persistence",
    qos: .utility
)

extension ContentViewModel {
    private struct StoredAudioEncodingSettings {
        let encoder: AudioEncoderOption
        let mode: AudioModeOption
        let sampleRate: SampleRateOption
        let bitRate: AudioBitRateOption
    }

    private static let videoSourceSettingsStorageKey = PersistedSettingsState().videoStorageKey
    private static let imageSourceSettingsStorageKey = PersistedSettingsState().imageStorageKey
    private static let audioSourceSettingsStorageKey = PersistedSettingsState().audioStorageKey

    private static func storedAudioEncodingSettings(
        from selection: AudioEncodingSelectionState
    ) -> StoredAudioEncodingSettings {
        StoredAudioEncodingSettings(
            encoder: selection.selectedEncoder,
            mode: selection.selectedMode,
            sampleRate: selection.selectedSampleRate,
            bitRate: selection.selectedBitRate
        )
    }

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

    private static func applyStoredAudioEncodingSettings(
        _ settings: StoredAudioEncodingSettings,
        to viewModel: ContentViewModel,
        encoder: ReferenceWritableKeyPath<ContentViewModel, AudioEncoderOption>,
        mode: ReferenceWritableKeyPath<ContentViewModel, AudioModeOption>,
        sampleRate: ReferenceWritableKeyPath<ContentViewModel, SampleRateOption>,
        bitRate: ReferenceWritableKeyPath<ContentViewModel, AudioBitRateOption>
    ) {
        viewModel[keyPath: encoder] = settings.encoder
        viewModel[keyPath: mode] = settings.mode
        viewModel[keyPath: sampleRate] = settings.sampleRate
        viewModel[keyPath: bitRate] = settings.bitRate
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
        Self.videoOutputFormatDescriptorValue.applyStoredSettings(
            applyingFlagKeyPath: \.settingsState.isApplyingVideoSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
            to: self,
            applyAdditionalSettings: {
                Self.applyVideoConversionSettings(settings, to: self)
            },
            postApply: {
                Self.videoOutputFormatDescriptorValue.ensureSelectedFormatIsAvailable(in: self)
                refreshVideoCodecOptions()
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
        Self.imageOutputFormatDescriptorValue.applyStoredSettings(
            applyingFlagKeyPath: \.settingsState.isApplyingImageSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            to: self,
            applyAdditionalSettings: {
                imageOptionsState.selectedResolution = settings.resolution
                imageOptionsState.selectedQuality = settings.quality
                imageOptionsState.selectedPNGCompressionLevel = settings.pngCompressionLevel
                imageOptionsState.preserveAnimation = settings.preserveAnimation
            },
            postApply: {
                Self.imageOutputFormatDescriptorValue.ensureSelectedFormatIsAvailable(in: self)
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
        Self.audioOutputFormatDescriptorValue.applyStoredSettings(
            applyingFlagKeyPath: \.settingsState.isApplyingAudioSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            to: self,
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
                Self.audioOutputFormatDescriptorValue.ensureSelectedFormatIsAvailable(in: self)
                refreshAudioCodecOptions()
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

    func saveSettings<Value: Encodable>(
        _ settings: Value,
        forKey storageKey: String,
        failureContext: String
    ) {
        persistedSettingsSaveQueue.async {
            do {
                let data = try JSONEncoder().encode(settings)
                UserDefaults.standard.set(data, forKey: storageKey)
            } catch {
                print("\(failureContext): \(error.localizedDescription)")
            }
        }
    }

    func loadSettings<Value: Decodable>(
        _ type: Value.Type,
        forKey storageKey: String,
        failureContext: String
    ) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("\(failureContext): \(error.localizedDescription)")
            return nil
        }
    }

    func loadPersistedSourceSettingsState() {
        settingsState.videoSettingsBySourceID =
            loadPersistedSourceSettings(
                [String: PersistedVideoConversionSettings].self,
                storageKey: Self.videoSourceSettingsStorageKey,
                failureContext: MediaKind.video.loadSettingsFailureContext,
                restore: { $0.restoredSettings }
            )
        settingsState.imageSettingsBySourceID =
            loadPersistedSourceSettings(
                [String: PersistedImageConversionSettings].self,
                storageKey: Self.imageSourceSettingsStorageKey,
                failureContext: MediaKind.image.loadSettingsFailureContext,
                restore: { $0.restoredSettings }
            )
        settingsState.audioSettingsBySourceID =
            loadPersistedSourceSettings(
                [String: PersistedAudioConversionSettings].self,
                storageKey: Self.audioSourceSettingsStorageKey,
                failureContext: MediaKind.audio.loadSettingsFailureContext,
                restore: { $0.restoredSettings }
            )
    }

    func persistSourceSettingsIfNeeded<Settings: Equatable>(
        isApplyingStoredSettings: Bool,
        sourceURL: URL?,
        settingsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [String: Settings]>,
        buildSettings: () -> Settings,
        savePersistedSettings: () -> Void
    ) {
        guard !isApplyingStoredSettings, let sourceURL else { return }

        let sourceID = sourceIdentifier(for: sourceURL)
        let updatedSettings = buildSettings()
        var settingsBySourceID = self[keyPath: settingsKeyPath]
        guard settingsBySourceID[sourceID] != updatedSettings else { return }

        settingsBySourceID[sourceID] = updatedSettings
        self[keyPath: settingsKeyPath] = settingsBySourceID
        savePersistedSettings()
    }

    func savePersistedSourceSettings<Settings: Equatable, Persisted: Encodable>(
        settingsBySourceID: [String: Settings],
        mapToPersisted: (Settings) -> Persisted,
        storageKey: String,
        failureContext: String
    ) {
        let persisted = settingsBySourceID.mapValues(mapToPersisted)
        saveSettings(
            persisted,
            forKey: storageKey,
            failureContext: failureContext
        )
    }

    func schedulePersistedSourceSettingsSave<Settings: Equatable, Persisted: Encodable>(
        _ pendingSaveTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        settingsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [String: Settings]>,
        mapToPersisted: @escaping (Settings) -> Persisted,
        storageKey: String,
        failureContext: String
    ) {
        scheduleDebouncedTask(pendingSaveTask) { viewModel in
            viewModel.savePersistedSourceSettings(
                settingsBySourceID: viewModel[keyPath: settingsKeyPath],
                mapToPersisted: mapToPersisted,
                storageKey: storageKey,
                failureContext: failureContext
            )
        }
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

    func loadPersistedSourceSettings<Settings, Persisted: Decodable>(
        _ type: [String: Persisted].Type,
        storageKey: String,
        failureContext: String,
        restore: (Persisted) -> Settings
    ) -> [String: Settings] {
        guard let decoded = loadSettings(
            type,
            forKey: storageKey,
            failureContext: failureContext
        ) else {
            return [:]
        }
        return decoded.mapValues(restore)
    }

    func applyDefaultSourceSettings(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        descriptor.applyDefaultSourceSettings(self)
    }

    func applyStoredSourceSettings(for sourceID: String, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        descriptor.applyStoredSourceSettings(self, sourceID)
    }

    func persistCurrentSourceSettingsIfNeeded(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        descriptor.persistCurrentSourceSettings(self)
    }
}
