import Foundation

extension ContentViewModel {
    func clampedProgress(_ rawProgress: Double) -> Double {
        ContentViewModelSupport.clampedProgress(rawProgress)
    }

    func sourceIdentifier(for url: URL) -> String {
        ContentViewModelSupport.sourceIdentifier(for: url)
    }

    func makeDeferredMainActorTask(
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            action(self)
        }
    }

    func scheduleDeferredTask(
        _ taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) {
        self[keyPath: taskKeyPath]?.cancel()
        self[keyPath: taskKeyPath] = makeDeferredMainActorTask(action: action)
    }

    func saveSettings<Value: Encodable>(
        _ settings: Value,
        forKey storageKey: String,
        failureContext: String
    ) {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("\(failureContext): \(error.localizedDescription)")
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

    func scheduleVideoFormatChangeHandling() {
        scheduleDeferredTask(\.pendingVideoFormatChangeTask) { viewModel in
            viewModel.refreshVideoCodecOptions()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    func scheduleVideoOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.pendingVideoOptionNormalizationTask) { viewModel in
            viewModel.normalizeVideoOptionDependencies()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    func scheduleAudioFormatChangeHandling() {
        scheduleDeferredTask(\.pendingAudioFormatChangeTask) { viewModel in
            viewModel.refreshAudioCodecOptions()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    func scheduleAudioOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.pendingAudioOptionNormalizationTask) { viewModel in
            viewModel.normalizeAudioOptionDependencies()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

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

    func persistCurrentImageSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: isApplyingStoredImageSettings,
            sourceURL: imageSourceURL,
            settingsKeyPath: \.imageSettingsBySourceID,
            buildSettings: {
                ImageConversionSettings(
                    outputFormatID: selectedImageOutputFormat.id,
                    resolution: selectedImageResolution,
                    quality: selectedImageQuality,
                    pngCompressionLevel: selectedPNGCompressionLevel,
                    preserveAnimation: preserveImageAnimation
                )
            },
            savePersistedSettings: savePersistedImageSettings
        )
    }

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

    func savePersistedSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: videoSettingsBySourceID,
            mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
            storageKey: videoSettingsStorageKey,
            failureContext: "Failed to persist video settings"
        )
    }

    func savePersistedImageSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: imageSettingsBySourceID,
            mapToPersisted: { PersistedImageConversionSettings(from: $0) },
            storageKey: imageSettingsStorageKey,
            failureContext: "Failed to persist image settings"
        )
    }

    func savePersistedAudioSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: audioSettingsBySourceID,
            mapToPersisted: { PersistedAudioConversionSettings(from: $0) },
            storageKey: audioSettingsStorageKey,
            failureContext: "Failed to persist audio settings"
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

    func loadPersistedImageSettings() -> [String: ImageConversionSettings] {
        loadPersistedSourceSettings(
            [String: PersistedImageConversionSettings].self,
            storageKey: imageSettingsStorageKey,
            failureContext: "Failed to load persisted image settings",
            restore: { $0.restoredSettings }
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
