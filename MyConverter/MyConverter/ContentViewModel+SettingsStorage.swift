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
        SourceSettingsDescriptor(
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
        SourceSettingsFlowDescriptor(
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
            postApply: { viewModel in
                viewModel.ensureSelectedOutputFormatIsAvailable(using: viewModel.videoOutputFormatDescriptor())
                viewModel.refreshVideoCodecOptions()
            }
        )
    }

    func imageSettingsDescriptor() -> SourceSettingsDescriptor<ImageConversionSettings, PersistedImageConversionSettings> {
        SourceSettingsDescriptor(
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
        SourceSettingsFlowDescriptor(
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
            },
            postApply: { viewModel in
                viewModel.ensureSelectedOutputFormatIsAvailable(using: viewModel.imageOutputFormatDescriptor())
            }
        )
    }

    func audioSettingsDescriptor() -> SourceSettingsDescriptor<AudioConversionSettings, PersistedAudioConversionSettings> {
        SourceSettingsDescriptor(
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
        SourceSettingsFlowDescriptor(
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
            postApply: { viewModel in
                viewModel.ensureSelectedOutputFormatIsAvailable(using: viewModel.audioOutputFormatDescriptor())
                viewModel.refreshAudioCodecOptions()
            }
        )
    }

    func sourceSettingsActions(for kind: MediaKind) -> SourceSettingsActions {
        switch kind {
        case .video:
            return SourceSettingsActions(
                applyDefault: { viewModel in
                    let descriptor = viewModel.videoSettingsFlowDescriptor()
                    viewModel.applySourceSettings(descriptor.defaultSettings(), using: descriptor)
                },
                applyForSourceID: { viewModel, sourceID in
                    viewModel.applySourceSettingsForSource(
                        sourceID: sourceID,
                        using: viewModel.videoSettingsFlowDescriptor()
                    )
                },
                persistCurrent: { viewModel in
                    viewModel.persistCurrentSourceSettingsIfNeeded(
                        using: viewModel.videoSettingsFlowDescriptor()
                    )
                }
            )
        case .image:
            return SourceSettingsActions(
                applyDefault: { viewModel in
                    let descriptor = viewModel.imageSettingsFlowDescriptor()
                    viewModel.applySourceSettings(descriptor.defaultSettings(), using: descriptor)
                },
                applyForSourceID: { viewModel, sourceID in
                    viewModel.applySourceSettingsForSource(
                        sourceID: sourceID,
                        using: viewModel.imageSettingsFlowDescriptor()
                    )
                },
                persistCurrent: { viewModel in
                    viewModel.persistCurrentSourceSettingsIfNeeded(
                        using: viewModel.imageSettingsFlowDescriptor()
                    )
                }
            )
        case .audio:
            return SourceSettingsActions(
                applyDefault: { viewModel in
                    let descriptor = viewModel.audioSettingsFlowDescriptor()
                    viewModel.applySourceSettings(descriptor.defaultSettings(), using: descriptor)
                },
                applyForSourceID: { viewModel, sourceID in
                    viewModel.applySourceSettingsForSource(
                        sourceID: sourceID,
                        using: viewModel.audioSettingsFlowDescriptor()
                    )
                },
                persistCurrent: { viewModel in
                    viewModel.persistCurrentSourceSettingsIfNeeded(
                        using: viewModel.audioSettingsFlowDescriptor()
                    )
                }
            )
        }
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
