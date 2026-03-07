import Foundation

private let persistedSettingsSaveQueue = DispatchQueue(
    label: "myconverter.settings.persistence",
    qos: .utility
)

extension ContentViewModel {
    struct SourceSettingsDescriptor<Settings, Persisted: Codable> {
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

    struct SourceSettingsFlowDescriptor<Settings, Persisted: Codable, Format> {
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

    func makeSourceSettingsDescriptor<Settings, Persisted: Codable>(
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

    func makeSourceSettingsFlowDescriptor<Settings, Persisted: Codable, Format>(
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

    func makeSourceSettingsActions<Settings, Persisted: Codable, Format>(
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

    func videoSettingsDescriptor() -> SourceSettingsDescriptor<VideoConversionSettings, PersistedVideoConversionSettings> {
        makeSourceSettingsDescriptor(
            isApplyingStoredSettings: \.settingsState.isApplyingVideoSettings,
            sourceURL: \.sourceURL,
            settingsBySourceID: \.settingsState.videoSettingsBySourceID,
            pendingSaveTask: \.taskState.pendingVideoSettingsSaveTask,
            storageKey: settingsState.videoStorageKey,
            saveFailureContext: "Failed to persist video settings",
            loadFailureContext: "Failed to load persisted video settings",
            mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
            restore: { $0.restoredSettings }
        )
    }

    func videoSettingsFlowDescriptor() -> SourceSettingsFlowDescriptor<
        VideoConversionSettings,
        PersistedVideoConversionSettings,
        VideoFormatOption
    > {
        makeSourceSettingsFlowDescriptor(
            storage: videoSettingsDescriptor(),
            formatDescriptor: videoOutputFormatDescriptor(),
            defaultSettings: { VideoConversionSettings() },
            outputFormatID: { $0.outputFormatID },
            normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
            buildCurrentSettings: { viewModel in
                VideoConversionSettings(
                    outputFormatID: viewModel.selectedOutputFormat.id,
                    videoEncoder: viewModel.selectedVideoEncoder,
                    resolution: viewModel.selectedResolution,
                    frameRate: viewModel.selectedFrameRate,
                    gifPlaybackSpeed: viewModel.selectedGIFPlaybackSpeed,
                    videoBitRate: viewModel.selectedVideoBitRate,
                    customVideoBitRate: viewModel.customVideoBitRate,
                    audioEncoder: viewModel.selectedAudioEncoder,
                    audioMode: viewModel.selectedAudioMode,
                    sampleRate: viewModel.selectedSampleRate,
                    audioBitRate: viewModel.selectedAudioBitRate
                )
            },
            applyAdditionalSettings: { viewModel, settings in
                viewModel.selectedVideoEncoder = settings.videoEncoder
                viewModel.selectedResolution = settings.resolution
                viewModel.selectedFrameRate = settings.frameRate
                viewModel.selectedGIFPlaybackSpeed = settings.gifPlaybackSpeed
                viewModel.selectedVideoBitRate = settings.videoBitRate
                viewModel.customVideoBitRate = settings.customVideoBitRate
                viewModel.selectedAudioEncoder = settings.audioEncoder
                viewModel.selectedAudioMode = settings.audioMode
                viewModel.selectedSampleRate = settings.sampleRate
                viewModel.selectedAudioBitRate = settings.audioBitRate
            },
            refreshDependentOptions: { $0.refreshVideoCodecOptions() }
        )
    }

    func imageSettingsDescriptor() -> SourceSettingsDescriptor<ImageConversionSettings, PersistedImageConversionSettings> {
        makeSourceSettingsDescriptor(
            isApplyingStoredSettings: \.settingsState.isApplyingImageSettings,
            sourceURL: \.imageSourceURL,
            settingsBySourceID: \.settingsState.imageSettingsBySourceID,
            pendingSaveTask: \.taskState.pendingImageSettingsSaveTask,
            storageKey: settingsState.imageStorageKey,
            saveFailureContext: "Failed to persist image settings",
            loadFailureContext: "Failed to load persisted image settings",
            mapToPersisted: { PersistedImageConversionSettings(from: $0) },
            restore: { $0.restoredSettings }
        )
    }

    func imageSettingsFlowDescriptor() -> SourceSettingsFlowDescriptor<
        ImageConversionSettings,
        PersistedImageConversionSettings,
        ImageFormatOption
    > {
        makeSourceSettingsFlowDescriptor(
            storage: imageSettingsDescriptor(),
            formatDescriptor: imageOutputFormatDescriptor(),
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
    }

    func audioSettingsDescriptor() -> SourceSettingsDescriptor<AudioConversionSettings, PersistedAudioConversionSettings> {
        makeSourceSettingsDescriptor(
            isApplyingStoredSettings: \.settingsState.isApplyingAudioSettings,
            sourceURL: \.audioSourceURL,
            settingsBySourceID: \.settingsState.audioSettingsBySourceID,
            pendingSaveTask: \.taskState.pendingAudioSettingsSaveTask,
            storageKey: settingsState.audioStorageKey,
            saveFailureContext: "Failed to persist audio settings",
            loadFailureContext: "Failed to load persisted audio settings",
            mapToPersisted: { PersistedAudioConversionSettings(from: $0) },
            restore: { $0.restoredSettings }
        )
    }

    func audioSettingsFlowDescriptor() -> SourceSettingsFlowDescriptor<
        AudioConversionSettings,
        PersistedAudioConversionSettings,
        AudioFormatOption
    > {
        makeSourceSettingsFlowDescriptor(
            storage: audioSettingsDescriptor(),
            formatDescriptor: audioOutputFormatDescriptor(),
            defaultSettings: { AudioConversionSettings() },
            outputFormatID: { $0.outputFormatID },
            normalizeStoredID: { $0.lowercased() },
            buildCurrentSettings: { viewModel in
                AudioConversionSettings(
                    outputFormatID: viewModel.selectedAudioOutputFormat.id,
                    audioEncoder: viewModel.selectedAudioOutputEncoder,
                    audioMode: viewModel.selectedAudioOutputMode,
                    sampleRate: viewModel.selectedAudioOutputSampleRate,
                    audioBitRate: viewModel.selectedAudioOutputBitRate
                )
            },
            applyAdditionalSettings: { viewModel, settings in
                viewModel.selectedAudioOutputEncoder = settings.audioEncoder
                viewModel.selectedAudioOutputMode = settings.audioMode
                viewModel.selectedAudioOutputSampleRate = settings.sampleRate
                viewModel.selectedAudioOutputBitRate = settings.audioBitRate
            },
            refreshDependentOptions: { $0.refreshAudioCodecOptions() }
        )
    }

    func sourceSettingsActions(for kind: MediaKind) -> SourceSettingsActions {
        mediaStateDescriptor(for: kind).sourceSettingsActions
    }

    func persistSourceSettingsIfNeeded<Settings>(
        isApplyingStoredSettings: Bool,
        sourceURL: URL?,
        settingsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [String: Settings]>,
        buildSettings: () -> Settings,
        savePersistedSettings: () -> Void
    ) {
        guard !isApplyingStoredSettings, let sourceURL else { return }

        var settingsBySourceID = self[keyPath: settingsKeyPath]
        settingsBySourceID[sourceIdentifier(for: sourceURL)] = buildSettings()
        self[keyPath: settingsKeyPath] = settingsBySourceID
        savePersistedSettings()
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

    func persistSourceSettingsIfNeeded<Settings, Persisted>(
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>,
        buildSettings: () -> Settings
    ) {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: self[keyPath: descriptor.isApplyingStoredSettings],
            sourceURL: self[keyPath: descriptor.sourceURL],
            settingsKeyPath: descriptor.settingsBySourceID,
            buildSettings: buildSettings,
            savePersistedSettings: {
                self.schedulePersistedSourceSettingsSave(using: descriptor)
            }
        )
    }

    func persistCurrentSourceSettingsIfNeeded<Settings, Persisted, Format>(
        using descriptor: SourceSettingsFlowDescriptor<Settings, Persisted, Format>
    ) {
        persistSourceSettingsIfNeeded(using: descriptor.storage) {
            descriptor.buildCurrentSettings(self)
        }
    }

    func savePersistedSourceSettings<Settings, Persisted: Encodable>(
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

    func schedulePersistedSourceSettingsSave<Settings, Persisted: Encodable>(
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>
    ) {
        scheduleDebouncedTask(descriptor.pendingSaveTask) { viewModel in
            viewModel.savePersistedSourceSettings(
                settingsBySourceID: viewModel[keyPath: descriptor.settingsBySourceID],
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

    func loadPersistedSourceSettings<Settings, Persisted>(
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>
    ) -> [String: Settings] {
        loadPersistedSourceSettings(
            [String: Persisted].self,
            storageKey: descriptor.storageKey,
            failureContext: descriptor.loadFailureContext,
            restore: descriptor.restore
        )
    }

    func applyStoredSettingsForSource<Settings, Persisted>(
        sourceID: String,
        using descriptor: SourceSettingsDescriptor<Settings, Persisted>,
        defaultSettings: @autoclosure () -> Settings,
        apply: (Settings) -> Void
    ) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: self[keyPath: descriptor.settingsBySourceID],
            defaultSettings: defaultSettings(),
            apply: apply
        )
    }

    func applySourceSettings<Settings, Persisted, Format>(
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

    func applySourceSettingsForSource<Settings, Persisted, Format>(
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
        sourceSettingsActions(for: kind).applyDefault(self)
    }

    func applyStoredSourceSettings(for sourceID: String, for kind: MediaKind) {
        sourceSettingsActions(for: kind).applyForSourceID(self, sourceID)
    }

    func persistCurrentSourceSettingsIfNeeded(for kind: MediaKind) {
        sourceSettingsActions(for: kind).persistCurrent(self)
    }
}
