import Foundation

extension ContentViewModel {
    func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        ContentViewModelSupport.uniqueStandardizedURLs(urls)
    }

    func isVideoInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isVideoInputURL(url)
    }

    func isImageInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isImageInputURL(url)
    }

    func isAudioInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isAudioInputURL(url)
    }

    func cancelTask(_ task: inout Task<Void, Never>?) {
        task?.cancel()
        task = nil
    }

    func assignPrimaryAndQueuedSources(
        _ urls: [URL],
        primaryKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        queuedKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>
    ) {
        self[keyPath: primaryKeyPath] = urls.first
        self[keyPath: queuedKeyPath] = Array(urls.dropFirst())
    }

    func applySelectedSources(
        _ urls: [URL],
        cancelAnalysisTask: () -> Void,
        assignSelection: ([URL]) -> Void,
        resetState: () -> Void,
        applyStoredSettingsForSourceID: (String) -> Void,
        analyzeSelection: ([URL]) -> Void
    ) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        cancelAnalysisTask()
        assignSelection(uniqueURLs)
        resetState()

        let sourceID = sourceIdentifier(for: firstURL)
        applyStoredSettingsForSourceID(sourceID)
        analyzeSelection(uniqueURLs)
    }

    func applyStoredSettingsForSource<Settings>(
        sourceID: String,
        settingsBySourceID: [String: Settings],
        defaultSettings: @autoclosure () -> Settings,
        apply: (Settings) -> Void
    ) {
        let stored = settingsBySourceID[sourceID] ?? defaultSettings()
        apply(stored)
    }

    func removeProcessedSource(
        _ processedURL: URL,
        from selectedSourceURLs: [URL],
        assignSelection: ([URL]) -> Void,
        onSelectionEmptied: () -> Void
    ) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = selectedSourceURLs.filter { sourceIdentifier(for: $0) != processedID }
        assignSelection(remainingSources)
        guard !remainingSources.isEmpty else {
            onSelectionEmptied()
            return
        }
    }

    func clearSelectedSourceState(
        cancelAnalysisTask: () -> Void,
        resetSelectionAndOutput: () -> Void,
        resetCompatibilityAndBatchState: () -> Void,
        resetFormatsAndSettings: () -> Void
    ) {
        cancelAnalysisTask()
        resetSelectionAndOutput()
        resetCompatibilityAndBatchState()
        resetFormatsAndSettings()
    }

    func assignVideoSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.sourceURL,
            queuedKeyPath: \.queuedSourceURLs
        )
    }

    func assignImageSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.imageSourceURL,
            queuedKeyPath: \.queuedImageSourceURLs
        )
    }

    func assignAudioSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.audioSourceURL,
            queuedKeyPath: \.queuedAudioSourceURLs
        )
    }

    func applyStoredVideoSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: videoSettingsBySourceID,
            defaultSettings: VideoConversionSettings(),
            apply: { settings in
                applyStoredSettings(settings)
            }
        )
    }

    func applyStoredImageSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: imageSettingsBySourceID,
            defaultSettings: ImageConversionSettings(),
            apply: { settings in
                applyStoredImageSettings(settings)
            }
        )
    }

    func applyStoredAudioSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: audioSettingsBySourceID,
            defaultSettings: AudioConversionSettings(),
            apply: { settings in
                applyStoredAudioSettings(settings)
            }
        )
    }

    func resetVideoConversionOutputs() {
        convertedURL = nil
        convertedURLs = []
        conversionErrorMessage = nil
    }

    func resetImageConversionOutputs() {
        convertedImageURL = nil
        convertedImageURLs = []
        imageConversionErrorMessage = nil
    }

    func resetAudioConversionOutputs() {
        convertedAudioURL = nil
        convertedAudioURLs = []
        audioConversionErrorMessage = nil
    }

    func resetVideoCompatibilityMessages() {
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil
    }

    func resetImageCompatibilityState(resetMetadata: Bool) {
        if resetMetadata {
            imageSourceFrameCount = 0
            imageSourceHasAlpha = false
        }
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil
    }

    func resetAudioCompatibilityMessages() {
        audioSourceCompatibilityErrorMessage = nil
        audioSourceCompatibilityWarningMessage = nil
    }

    func clearSelectedSource() {
        clearSelectedVideoSource()
    }

    func clearSelectedVideoSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&sourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                sourceURL = nil
                queuedSourceURLs = []
                resetVideoConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetVideoCompatibilityMessages()
                isAnalyzingSource = false
                currentVideoBatchIndex = 0
                totalVideoBatchCount = 0
            },
            resetFormatsAndSettings: {
                availableOutputFormats = VideoConversionEngine.defaultOutputFormats()
                applyStoredSettings(.init())
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    func clearSelectedImageSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&imageSourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                imageSourceURL = nil
                queuedImageSourceURLs = []
                resetImageConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetImageCompatibilityState(resetMetadata: true)
                isAnalyzingImageSource = false
                currentImageBatchIndex = 0
                totalImageBatchCount = 0
            },
            resetFormatsAndSettings: {
                availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()
                applyStoredImageSettings(.init())
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    func clearSelectedAudioSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&audioSourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                audioSourceURL = nil
                queuedAudioSourceURLs = []
                resetAudioConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetAudioCompatibilityMessages()
                isAnalyzingAudioSource = false
                currentAudioBatchIndex = 0
                totalAudioBatchCount = 0
            },
            resetFormatsAndSettings: {
                availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()
                applyStoredAudioSettings(.init())
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }

    func labeledCapabilityMessage(_ message: String, for sourceURL: URL, totalCount: Int) -> String {
        ContentViewModelSupport.labeledCapabilityMessage(message, for: sourceURL, totalCount: totalCount)
    }

    func joinedCapabilityMessages(_ messages: [String]) -> String? {
        ContentViewModelSupport.joinedCapabilityMessages(messages)
    }
}
