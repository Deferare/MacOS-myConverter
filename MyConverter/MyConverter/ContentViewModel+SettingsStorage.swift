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

    struct SourceSettingsDescriptor<Settings: Equatable, Persisted: Codable> {
        let isApplyingStoredSettings: ReferenceWritableKeyPath<ContentViewModel, Bool>
        let sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let settingsBySourceID: ReferenceWritableKeyPath<ContentViewModel, [String: Settings]>
        let pendingSaveTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let storageKey: String
        let saveFailureContext: String
        let loadFailureContext: String
        let mapToPersisted: (Settings) -> Persisted
        let restore: (Persisted) -> Settings
    }

    func sourceSettingsValue<Settings, Persisted, Value>(
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>,
        _ keyPath: KeyPath<SourceSettingsDescriptor<Settings, Persisted>, ReferenceWritableKeyPath<ContentViewModel, Value>>
    ) -> Value {
        self[keyPath: descriptor[keyPath: keyPath]]
    }

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
            applyingFlagKeyPath: Self.videoSourceSettingsStorageValue.isApplyingStoredSettings,
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
            using: Self.videoSourceSettingsStorageValue,
            defaultSettings: VideoConversionSettings(),
            apply: { self.applyVideoSourceSettings($0) }
        )
    }

    func persistCurrentVideoSourceSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(using: Self.videoSourceSettingsStorageValue) {
            currentVideoSourceSettings()
        }
    }

    static let videoSourceSettingsStorageValue = SourceSettingsDescriptor(
        isApplyingStoredSettings: \.settingsState.isApplyingVideoSettings,
        sourceURL: \.videoRuntimeState.media.sourceURL,
        settingsBySourceID: \.settingsState.videoSettingsBySourceID,
        pendingSaveTask: \.taskState.pendingVideoSettingsSaveTask,
        storageKey: PersistedSettingsState().videoStorageKey,
        saveFailureContext: MediaKind.video.saveSettingsFailureContext,
        loadFailureContext: MediaKind.video.loadSettingsFailureContext,
        mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
        restore: { $0.restoredSettings }
    )

    static let imageSourceSettingsStorageValue = SourceSettingsDescriptor(
        isApplyingStoredSettings: \.settingsState.isApplyingImageSettings,
        sourceURL: \.imageRuntimeState.media.sourceURL,
        settingsBySourceID: \.settingsState.imageSettingsBySourceID,
        pendingSaveTask: \.taskState.pendingImageSettingsSaveTask,
        storageKey: PersistedSettingsState().imageStorageKey,
        saveFailureContext: MediaKind.image.saveSettingsFailureContext,
        loadFailureContext: MediaKind.image.loadSettingsFailureContext,
        mapToPersisted: { PersistedImageConversionSettings(from: $0) },
        restore: { $0.restoredSettings }
    )

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
            applyingFlagKeyPath: Self.imageSourceSettingsStorageValue.isApplyingStoredSettings,
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
            using: Self.imageSourceSettingsStorageValue,
            defaultSettings: ImageConversionSettings(),
            apply: { self.applyImageSourceSettings($0) }
        )
    }

    func persistCurrentImageSourceSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(using: Self.imageSourceSettingsStorageValue) {
            currentImageSourceSettings()
        }
    }

    static let audioSourceSettingsStorageValue = SourceSettingsDescriptor(
        isApplyingStoredSettings: \.settingsState.isApplyingAudioSettings,
        sourceURL: \.audioRuntimeState.media.sourceURL,
        settingsBySourceID: \.settingsState.audioSettingsBySourceID,
        pendingSaveTask: \.taskState.pendingAudioSettingsSaveTask,
        storageKey: PersistedSettingsState().audioStorageKey,
        saveFailureContext: MediaKind.audio.saveSettingsFailureContext,
        loadFailureContext: MediaKind.audio.loadSettingsFailureContext,
        mapToPersisted: { PersistedAudioConversionSettings(from: $0) },
        restore: { $0.restoredSettings }
    )

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
            applyingFlagKeyPath: Self.audioSourceSettingsStorageValue.isApplyingStoredSettings,
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
            using: Self.audioSourceSettingsStorageValue,
            defaultSettings: AudioConversionSettings(),
            apply: { self.applyAudioSourceSettings($0) }
        )
    }

    func persistCurrentAudioSourceSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(using: Self.audioSourceSettingsStorageValue) {
            currentAudioSourceSettings()
        }
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
            loadPersistedSourceSettings(using: Self.videoSourceSettingsStorageValue)
        settingsState.imageSettingsBySourceID =
            loadPersistedSourceSettings(using: Self.imageSourceSettingsStorageValue)
        settingsState.audioSettingsBySourceID =
            loadPersistedSourceSettings(using: Self.audioSourceSettingsStorageValue)
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

    func persistSourceSettingsIfNeeded<Settings: Equatable, Persisted>(
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>,
        buildSettings: () -> Settings
    ) {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: sourceSettingsValue(using: descriptor, \.isApplyingStoredSettings),
            sourceURL: sourceSettingsValue(using: descriptor, \.sourceURL),
            settingsKeyPath: descriptor.settingsBySourceID,
            buildSettings: buildSettings,
            savePersistedSettings: {
                self.schedulePersistedSourceSettingsSave(using: descriptor)
            }
        )
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
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>
    ) {
        scheduleDebouncedTask(descriptor.pendingSaveTask) { viewModel in
            viewModel.savePersistedSourceSettings(
                settingsBySourceID: viewModel.sourceSettingsValue(using: descriptor, \.settingsBySourceID),
                mapToPersisted: descriptor.mapToPersisted,
                storageKey: descriptor.storageKey,
                failureContext: descriptor.saveFailureContext
            )
        }
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

    func loadPersistedSourceSettings<Settings: Equatable, Persisted>(
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>
    ) -> [String: Settings] {
        loadPersistedSourceSettings(
            [String: Persisted].self,
            storageKey: descriptor.storageKey,
            failureContext: descriptor.loadFailureContext,
            restore: descriptor.restore
        )
    }

    func applyStoredSettingsForSource<Settings: Equatable, Persisted>(
        sourceID: String,
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>,
        defaultSettings: @autoclosure () -> Settings,
        apply: (Settings) -> Void
    ) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: sourceSettingsValue(using: descriptor, \.settingsBySourceID),
            defaultSettings: defaultSettings(),
            apply: apply
        )
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
