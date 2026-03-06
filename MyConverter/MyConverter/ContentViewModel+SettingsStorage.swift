import Foundation

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
}
