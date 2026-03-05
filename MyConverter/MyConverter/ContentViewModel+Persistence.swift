import Foundation

extension ContentViewModel {
    // MARK: - Persistence

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

    func withSettingsApplicationFlag(
        _ keyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        operation: () -> Void
    ) {
        self[keyPath: keyPath] = true
        defer { self[keyPath: keyPath] = false }
        operation()
    }

    func applyStoredFormatSelection<Format>(
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String
    ) {
        guard let normalizedStoredID = normalizeStoredID(storedFormatID),
              let matchingFormat = options.first(where: { formatNormalizedID($0) == normalizedStoredID }) else {
            return
        }
        self[keyPath: selectedFormatKeyPath] = matchingFormat
    }

    func applyStoredSourceSettings<Format>(
        applyingFlagKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String,
        applyAdditionalSettings: () -> Void,
        postApply: () -> Void
    ) {
        withSettingsApplicationFlag(applyingFlagKeyPath) {
            applyStoredFormatSelection(
                storedFormatID: storedFormatID,
                normalizeStoredID: normalizeStoredID,
                options: options,
                selectedFormatKeyPath: selectedFormatKeyPath,
                formatNormalizedID: formatNormalizedID
            )
            applyAdditionalSettings()
        }
        postApply()
    }

    func applyStoredSettings(_ settings: VideoConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
            options: outputFormatOptions,
            selectedFormatKeyPath: \.selectedOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedVideoEncoder = settings.videoEncoder
                selectedResolution = settings.resolution
                selectedFrameRate = settings.frameRate
                selectedGIFPlaybackSpeed = settings.gifPlaybackSpeed
                selectedVideoBitRate = settings.videoBitRate
                customVideoBitRate = settings.customVideoBitRate
                selectedAudioEncoder = settings.audioEncoder
                selectedAudioMode = settings.audioMode
                selectedSampleRate = settings.sampleRate
                selectedAudioBitRate = settings.audioBitRate
            },
            postApply: {
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    func applyStoredImageSettings(_ settings: ImageConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredImageSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            options: imageOutputFormatOptions,
            selectedFormatKeyPath: \.selectedImageOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedImageResolution = settings.resolution
                selectedImageQuality = settings.quality
                selectedPNGCompressionLevel = settings.pngCompressionLevel
                preserveImageAnimation = settings.preserveAnimation
            },
            postApply: {
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    func applyStoredAudioSettings(_ settings: AudioConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredAudioSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            options: audioOutputFormatOptions,
            selectedFormatKeyPath: \.selectedAudioOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedAudioOutputEncoder = settings.audioEncoder
                selectedAudioOutputMode = settings.audioMode
                selectedAudioOutputSampleRate = settings.sampleRate
                selectedAudioOutputBitRate = settings.audioBitRate
            },
            postApply: {
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }

    func ensureSelectedFormatIsAvailable<Format>(
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String,
        preferredSelection: ([Format]) -> Format?
    ) {
        guard !options.isEmpty else { return }
        let selectedFormat = self[keyPath: selectedFormatKeyPath]
        guard !options.contains(where: { formatNormalizedID($0) == formatNormalizedID(selectedFormat) }),
              let preferredFormat = preferredSelection(options) else {
            return
        }
        self[keyPath: selectedFormatKeyPath] = preferredFormat
    }

    func ensureSelectedImageOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: imageOutputFormatOptions,
            selectedFormatKeyPath: \.selectedImageOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: { $0.first }
        )
    }

    func ensureSelectedAudioOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: audioOutputFormatOptions,
            selectedFormatKeyPath: \.selectedAudioOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: AudioFormatOption.defaultSelection(from:)
        )
    }

    func ensureSelectedVideoOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: outputFormatOptions,
            selectedFormatKeyPath: \.selectedOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: VideoFormatOption.defaultSelection(from:)
        )
    }

    func updateSelectedOptionIfNeeded<Option: Equatable>(
        options: [Option],
        selectedOptionKeyPath: ReferenceWritableKeyPath<ContentViewModel, Option>,
        preferredOption: ([Option]) -> Option?
    ) {
        let selected = self[keyPath: selectedOptionKeyPath]
        guard !options.contains(selected),
              let preferred = preferredOption(options) else {
            return
        }
        self[keyPath: selectedOptionKeyPath] = preferred
    }

    func refreshVideoCodecOptions() {
        let format = selectedOutputFormat
        availableVideoEncoders = VideoConversionEngine.availableVideoEncoders(for: format)
        availableAudioEncoders = format.supportsAudioTrack
            ? VideoConversionEngine.availableAudioEncoders(for: format)
            : []

        updateSelectedOptionIfNeeded(
            options: availableVideoEncoders,
            selectedOptionKeyPath: \.selectedVideoEncoder,
            preferredOption: ContentViewModelSupport.preferredVideoEncoder(from:)
        )

        if format.supportsAudioTrack {
            updateSelectedOptionIfNeeded(
                options: availableAudioEncoders,
                selectedOptionKeyPath: \.selectedAudioEncoder,
                preferredOption: ContentViewModelSupport.preferredAudioEncoder(from:)
            )
        }

        normalizeVideoOptionDependencies()
    }

    func refreshAudioCodecOptions() {
        let format = selectedAudioOutputFormat
        availableAudioOutputEncoders = VideoConversionEngine.availableAudioEncoders(for: format)

        let effectiveOptions: [AudioEncoderOption]
        if !availableAudioOutputEncoders.isEmpty {
            effectiveOptions = availableAudioOutputEncoders
        } else if audioSourceURL == nil && format.allowsFFmpegAutomaticAudioCodec {
            effectiveOptions = [.auto]
        } else {
            effectiveOptions = []
        }

        updateSelectedOptionIfNeeded(
            options: effectiveOptions,
            selectedOptionKeyPath: \.selectedAudioOutputEncoder,
            preferredOption: {
                ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: $0)
            }
        )

        normalizeAudioOptionDependencies()
    }

    func normalizeVideoOptionDependencies() {
        if !selectedVideoEncoder.supportsVideoBitRate && selectedVideoBitRate != .auto {
            selectedVideoBitRate = .auto
        }

        if !shouldShowAudioSettings {
            if selectedAudioEncoder != .auto {
                selectedAudioEncoder = .auto
            }
            if selectedAudioMode != .auto {
                selectedAudioMode = .auto
            }
            if selectedAudioBitRate != .auto {
                selectedAudioBitRate = .auto
            }
            return
        }

        if !selectedAudioEncoder.supportsAudioBitRate && selectedAudioBitRate != .auto {
            selectedAudioBitRate = .auto
        }
    }

    func normalizeAudioOptionDependencies() {
        let options = audioOutputEncoderOptions
        if !options.isEmpty,
           !options.contains(selectedAudioOutputEncoder),
           let preferred = ContentViewModelSupport.preferredAudioOutputEncoder(
               for: selectedAudioOutputFormat,
               from: options
           ) {
            selectedAudioOutputEncoder = preferred
        }

        if !selectedAudioOutputEncoder.supportsAudioBitRate && selectedAudioOutputBitRate != .auto {
            selectedAudioOutputBitRate = .auto
        }
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
