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

    struct SourceSettingsFlowDescriptor<Settings: Equatable, Persisted: Codable, Format> {
        let storage: SourceSettingsDescriptor<Settings, Persisted>
        let formatDescriptor: OutputFormatDescriptor<Format>
        let defaultSettings: () -> Settings
        let outputFormatID: (Settings) -> String
        let normalizeStoredID: (String) -> String?
        let buildCurrentSettings: (ContentViewModel) -> Settings
        let applyAdditionalSettings: (ContentViewModel, Settings) -> Void
        let postApply: (ContentViewModel) -> Void
    }

    struct SourceSettingsActions {
        let applyDefault: (ContentViewModel) -> Void
        let applyForSourceID: (ContentViewModel, String) -> Void
        let persistCurrent: (ContentViewModel) -> Void
    }

    struct SourceSettingsComponents<Settings: Equatable, Persisted: Codable, Format> {
        let storage: SourceSettingsDescriptor<Settings, Persisted>
        let flow: SourceSettingsFlowDescriptor<Settings, Persisted, Format>
    }

    static func makeSourceSettingsDescriptor<Settings: Equatable, Persisted: Codable>(
        isApplyingStoredSettings: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        settingsBySourceID: ReferenceWritableKeyPath<ContentViewModel, [String: Settings]>,
        pendingSaveTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        storageKey: String,
        saveFailureContext: String,
        loadFailureContext: String,
        mapToPersisted: @escaping (Settings) -> Persisted,
        restore: @escaping (Persisted) -> Settings
    ) -> SourceSettingsDescriptor<Settings, Persisted> {
        SourceSettingsDescriptor(
            isApplyingStoredSettings: isApplyingStoredSettings,
            sourceURL: sourceURL,
            settingsBySourceID: settingsBySourceID,
            pendingSaveTask: pendingSaveTask,
            storageKey: storageKey,
            saveFailureContext: saveFailureContext,
            loadFailureContext: loadFailureContext,
            mapToPersisted: mapToPersisted,
            restore: restore
        )
    }

    func sourceSettingsValue<Settings, Persisted, Value>(
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>,
        _ keyPath: KeyPath<SourceSettingsDescriptor<Settings, Persisted>, ReferenceWritableKeyPath<ContentViewModel, Value>>
    ) -> Value {
        self[keyPath: descriptor[keyPath: keyPath]]
    }

    static func makeSourceSettingsFlowDescriptor<Settings: Equatable, Persisted: Codable, Format>(
        storage: SourceSettingsDescriptor<Settings, Persisted>,
        formatDescriptor: OutputFormatDescriptor<Format>,
        defaultSettings: @escaping () -> Settings,
        outputFormatID: @escaping (Settings) -> String,
        normalizeStoredID: @escaping (String) -> String?,
        buildCurrentSettings: @escaping (ContentViewModel) -> Settings,
        applyAdditionalSettings: @escaping (ContentViewModel, Settings) -> Void,
        refreshDependentOptions: @escaping (ContentViewModel) -> Void = { _ in }
    ) -> SourceSettingsFlowDescriptor<Settings, Persisted, Format> {
        SourceSettingsFlowDescriptor(
            storage: storage,
            formatDescriptor: formatDescriptor,
            defaultSettings: defaultSettings,
            outputFormatID: outputFormatID,
            normalizeStoredID: normalizeStoredID,
            buildCurrentSettings: buildCurrentSettings,
            applyAdditionalSettings: applyAdditionalSettings,
            postApply: { viewModel in
                viewModel.ensureSelectedOutputFormatIsAvailable(using: formatDescriptor)
                refreshDependentOptions(viewModel)
            }
        )
    }

    static func makeSourceSettingsComponents<Settings: Equatable, Persisted: Codable, Format>(
        storage: SourceSettingsDescriptor<Settings, Persisted>,
        formatDescriptor: OutputFormatDescriptor<Format>,
        defaultSettings: @escaping () -> Settings,
        outputFormatID: @escaping (Settings) -> String,
        normalizeStoredID: @escaping (String) -> String?,
        buildCurrentSettings: @escaping (ContentViewModel) -> Settings,
        applyAdditionalSettings: @escaping (ContentViewModel, Settings) -> Void,
        refreshDependentOptions: @escaping (ContentViewModel) -> Void = { _ in }
    ) -> SourceSettingsComponents<Settings, Persisted, Format> {
        SourceSettingsComponents(
            storage: storage,
            flow: Self.makeSourceSettingsFlowDescriptor(
                storage: storage,
                formatDescriptor: formatDescriptor,
                defaultSettings: defaultSettings,
                outputFormatID: outputFormatID,
                normalizeStoredID: normalizeStoredID,
                buildCurrentSettings: buildCurrentSettings,
                applyAdditionalSettings: applyAdditionalSettings,
                refreshDependentOptions: refreshDependentOptions
            )
        )
    }

    static func makeSourceSettingsActions<Settings: Equatable, Persisted: Codable, Format>(
        using descriptor: @escaping (ContentViewModel) -> SourceSettingsFlowDescriptor<Settings, Persisted, Format>
    ) -> SourceSettingsActions {
        SourceSettingsActions(
            applyDefault: { viewModel in
                let flow = descriptor(viewModel)
                viewModel.applySourceSettings(flow.defaultSettings(), using: flow)
            },
            applyForSourceID: { viewModel, sourceID in
                viewModel.applySourceSettingsForSource(
                    sourceID: sourceID,
                    using: descriptor(viewModel)
                )
            },
            persistCurrent: { viewModel in
                viewModel.persistCurrentSourceSettingsIfNeeded(using: descriptor(viewModel))
            }
        )
    }

    private static func makeSourceSettingsStorageDescriptor<Settings: Equatable, Persisted: Codable>(
        kind: MediaKind,
        isApplyingStoredSettings: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        settingsBySourceID: ReferenceWritableKeyPath<ContentViewModel, [String: Settings]>,
        pendingSaveTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        storageKey: String,
        mapToPersisted: @escaping (Settings) -> Persisted,
        restore: @escaping (Persisted) -> Settings
    ) -> SourceSettingsDescriptor<Settings, Persisted> {
        let mediaDescriptor = kind.descriptor
        return Self.makeSourceSettingsDescriptor(
            isApplyingStoredSettings: isApplyingStoredSettings,
            sourceURL: sourceURL,
            settingsBySourceID: settingsBySourceID,
            pendingSaveTask: pendingSaveTask,
            storageKey: storageKey,
            saveFailureContext: mediaDescriptor.saveSettingsFailureContext,
            loadFailureContext: mediaDescriptor.loadSettingsFailureContext,
            mapToPersisted: mapToPersisted,
            restore: restore
        )
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

    static let videoSourceSettingsComponentsValue = makeSourceSettingsComponents(
        storage: makeSourceSettingsStorageDescriptor(
            kind: .video,
            isApplyingStoredSettings: \.settingsState.isApplyingVideoSettings,
            sourceURL: \.sourceURL,
            settingsBySourceID: \.settingsState.videoSettingsBySourceID,
            pendingSaveTask: \.taskState.pendingVideoSettingsSaveTask,
            storageKey: PersistedSettingsState().videoStorageKey,
            mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
            restore: { $0.restoredSettings }
        ),
        formatDescriptor: videoOutputFormatDescriptorValue,
        defaultSettings: { VideoConversionSettings() },
        outputFormatID: { $0.outputFormatID },
        normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
        buildCurrentSettings: { viewModel in
            let audioSettings = storedAudioEncodingSettings(
                from: viewModel.videoAudioEncodingSelectionState
            )
            return VideoConversionSettings(
                outputFormatID: viewModel.selectedOutputFormat.id,
                videoEncoder: viewModel.selectedVideoEncoder,
                resolution: viewModel.selectedResolution,
                frameRate: viewModel.selectedFrameRate,
                gifPlaybackSpeed: viewModel.selectedGIFPlaybackSpeed,
                videoBitRate: viewModel.selectedVideoBitRate,
                customVideoBitRate: viewModel.customVideoBitRate,
                audioEncoder: audioSettings.encoder,
                audioMode: audioSettings.mode,
                sampleRate: audioSettings.sampleRate,
                audioBitRate: audioSettings.bitRate
            )
        },
        applyAdditionalSettings: { viewModel, settings in
            viewModel.selectedVideoEncoder = settings.videoEncoder
            viewModel.selectedResolution = settings.resolution
            viewModel.selectedFrameRate = settings.frameRate
            viewModel.selectedGIFPlaybackSpeed = settings.gifPlaybackSpeed
            viewModel.selectedVideoBitRate = settings.videoBitRate
            viewModel.customVideoBitRate = settings.customVideoBitRate
            applyStoredAudioEncodingSettings(
                StoredAudioEncodingSettings(
                    encoder: settings.audioEncoder,
                    mode: settings.audioMode,
                    sampleRate: settings.sampleRate,
                    bitRate: settings.audioBitRate
                ),
                to: viewModel,
                encoder: \.selectedAudioEncoder,
                mode: \.selectedAudioMode,
                sampleRate: \.selectedSampleRate,
                bitRate: \.selectedAudioBitRate
            )
        },
        refreshDependentOptions: { $0.refreshVideoCodecOptions() }
    )

    static let imageSourceSettingsComponentsValue = makeSourceSettingsComponents(
        storage: makeSourceSettingsStorageDescriptor(
            kind: .image,
            isApplyingStoredSettings: \.settingsState.isApplyingImageSettings,
            sourceURL: \.imageRuntimeState.media.sourceURL,
            settingsBySourceID: \.settingsState.imageSettingsBySourceID,
            pendingSaveTask: \.taskState.pendingImageSettingsSaveTask,
            storageKey: PersistedSettingsState().imageStorageKey,
            mapToPersisted: { PersistedImageConversionSettings(from: $0) },
            restore: { $0.restoredSettings }
        ),
        formatDescriptor: imageOutputFormatDescriptorValue,
        defaultSettings: { ImageConversionSettings() },
        outputFormatID: { $0.outputFormatID },
        normalizeStoredID: { $0.lowercased() },
        buildCurrentSettings: { viewModel in
            ImageConversionSettings(
                outputFormatID: viewModel.selectedImageOutputFormat.id,
                resolution: viewModel.selectedImageResolution,
                quality: viewModel.selectedImageQuality,
                pngCompressionLevel: viewModel.selectedPNGCompressionLevel,
                preserveAnimation: viewModel.preserveImageAnimation
            )
        },
        applyAdditionalSettings: { viewModel, settings in
            viewModel.selectedImageResolution = settings.resolution
            viewModel.selectedImageQuality = settings.quality
            viewModel.selectedPNGCompressionLevel = settings.pngCompressionLevel
            viewModel.preserveImageAnimation = settings.preserveAnimation
        }
    )

    static let audioSourceSettingsComponentsValue = makeSourceSettingsComponents(
        storage: makeSourceSettingsStorageDescriptor(
            kind: .audio,
            isApplyingStoredSettings: \.settingsState.isApplyingAudioSettings,
            sourceURL: \.audioRuntimeState.media.sourceURL,
            settingsBySourceID: \.settingsState.audioSettingsBySourceID,
            pendingSaveTask: \.taskState.pendingAudioSettingsSaveTask,
            storageKey: PersistedSettingsState().audioStorageKey,
            mapToPersisted: { PersistedAudioConversionSettings(from: $0) },
            restore: { $0.restoredSettings }
        ),
        formatDescriptor: audioOutputFormatDescriptorValue,
        defaultSettings: { AudioConversionSettings() },
        outputFormatID: { $0.outputFormatID },
        normalizeStoredID: { $0.lowercased() },
        buildCurrentSettings: { viewModel in
            let audioSettings = storedAudioEncodingSettings(
                from: viewModel.audioOutputEncodingSelectionState
            )
            return AudioConversionSettings(
                outputFormatID: viewModel.selectedAudioOutputFormat.id,
                audioEncoder: audioSettings.encoder,
                audioMode: audioSettings.mode,
                sampleRate: audioSettings.sampleRate,
                audioBitRate: audioSettings.bitRate
            )
        },
        applyAdditionalSettings: { viewModel, settings in
            applyStoredAudioEncodingSettings(
                StoredAudioEncodingSettings(
                    encoder: settings.audioEncoder,
                    mode: settings.audioMode,
                    sampleRate: settings.sampleRate,
                    bitRate: settings.audioBitRate
                ),
                to: viewModel,
                encoder: \.selectedAudioOutputEncoder,
                mode: \.selectedAudioOutputMode,
                sampleRate: \.selectedAudioOutputSampleRate,
                bitRate: \.selectedAudioOutputBitRate
            )
        },
        refreshDependentOptions: { $0.refreshAudioCodecOptions() }
    )

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
            loadPersistedSourceSettings(using: Self.videoSourceSettingsComponentsValue.storage)
        settingsState.imageSettingsBySourceID =
            loadPersistedSourceSettings(using: Self.imageSourceSettingsComponentsValue.storage)
        settingsState.audioSettingsBySourceID =
            loadPersistedSourceSettings(using: Self.audioSourceSettingsComponentsValue.storage)
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

    func persistCurrentSourceSettingsIfNeeded<Settings: Equatable, Persisted, Format>(
        using descriptor: SourceSettingsFlowDescriptor<Settings, Persisted, Format>
    ) {
        persistSourceSettingsIfNeeded(using: descriptor.storage) {
            descriptor.buildCurrentSettings(self)
        }
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

    func applySourceSettings<Settings: Equatable, Persisted, Format>(
        _ settings: Settings,
        using descriptor: SourceSettingsFlowDescriptor<Settings, Persisted, Format>
    ) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: descriptor.storage.isApplyingStoredSettings,
            storedFormatID: descriptor.outputFormatID(settings),
            normalizeStoredID: descriptor.normalizeStoredID,
            formatDescriptor: descriptor.formatDescriptor,
            applyAdditionalSettings: {
                descriptor.applyAdditionalSettings(self, settings)
            },
            postApply: {
                descriptor.postApply(self)
            }
        )
    }

    func applySourceSettingsForSource<Settings: Equatable, Persisted, Format>(
        sourceID: String,
        using descriptor: SourceSettingsFlowDescriptor<Settings, Persisted, Format>
    ) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            using: descriptor.storage,
            defaultSettings: descriptor.defaultSettings(),
            apply: {
                applySourceSettings($0, using: descriptor)
            }
        )
    }

    func applyDefaultSourceSettings(for kind: MediaKind) {
        mediaStateDescriptor(for: kind).sourceSettingsActions.applyDefault(self)
    }

    func applyStoredSourceSettings(for sourceID: String, for kind: MediaKind) {
        mediaStateDescriptor(for: kind).sourceSettingsActions.applyForSourceID(self, sourceID)
    }

    func persistCurrentSourceSettingsIfNeeded(for kind: MediaKind) {
        mediaStateDescriptor(for: kind).sourceSettingsActions.persistCurrent(self)
    }
}
