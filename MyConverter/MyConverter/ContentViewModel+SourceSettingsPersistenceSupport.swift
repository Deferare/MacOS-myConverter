import Foundation

private let persistedSettingsSaveQueue = DispatchQueue(
    label: "myconverter.settings.persistence",
    qos: .utility
)

extension ContentViewModel {
    struct StoredAudioEncodingSettings {
        let encoder: AudioEncoderOption
        let mode: AudioModeOption
        let sampleRate: SampleRateOption
        let bitRate: AudioBitRateOption
    }

    static let videoSourceSettingsStorageKey = PersistedSettingsState().videoStorageKey
    static let imageSourceSettingsStorageKey = PersistedSettingsState().imageStorageKey
    static let audioSourceSettingsStorageKey = PersistedSettingsState().audioStorageKey

    static func storedAudioEncodingSettings(
        from selection: AudioEncodingSelectionState
    ) -> StoredAudioEncodingSettings {
        StoredAudioEncodingSettings(
            encoder: selection.selectedEncoder,
            mode: selection.selectedMode,
            sampleRate: selection.selectedSampleRate,
            bitRate: selection.selectedBitRate
        )
    }

    static func applyStoredAudioEncodingSettings(
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
}
