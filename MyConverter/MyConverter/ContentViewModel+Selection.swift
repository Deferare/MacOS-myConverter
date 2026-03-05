import AppKit
import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    // MARK: - Input Handling

    func preferredImportTypes(for selectedTab: ConverterTab) -> [UTType] {
        switch selectedTab {
        case .video:
            let mkvType = UTType(filenameExtension: "mkv")
            return [.movie, .video, mkvType].compactMap { $0 }
        case .image:
            return [.image]
        case .audio:
            return [.audio, .audiovisualContent]
        case .about:
            return [.item]
        }
    }

    func requestFileImport() {
        isImporting = true
    }

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

    func moveSelectedSource(
        from draggedURL: URL,
        to targetURL: URL,
        isConversionRunning: Bool,
        currentPrimaryURL: URL?,
        selectedSourceURLs: [URL],
        assignSelection: ([URL]) -> Void,
        cancelAnalysisTask: () -> Void,
        resetCompatibilityState: () -> Void,
        applyStoredSettingsForSourceID: (String) -> Void,
        analyzeSelection: ([URL]) -> Void
    ) {
        guard !isConversionRunning else { return }
        let previousPrimaryID = currentPrimaryURL.map(sourceIdentifier(for:))
        guard let reordered = reorderedURLsByMoving(draggedURL, to: targetURL, in: selectedSourceURLs) else {
            return
        }

        assignSelection(reordered)

        guard let newPrimarySourceURL = reordered.first else { return }
        guard sourceIdentifier(for: newPrimarySourceURL) != previousPrimaryID else { return }

        cancelAnalysisTask()
        resetCompatibilityState()

        let sourceID = sourceIdentifier(for: newPrimarySourceURL)
        applyStoredSettingsForSourceID(sourceID)
        analyzeSelection(reordered)
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

    func applyImportedSources(
        _ urls: [URL],
        accept: (URL) -> Bool,
        applySelection: ([URL]) -> Void
    ) {
        let filtered = urls.filter(accept)
        guard !filtered.isEmpty else { return }
        applySelection(filtered)
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

    func handleFileImportResult(_ result: Result<[URL], Error>, for selectedTab: ConverterTab) {
        switch result {
        case .success(let urls):
            let selected = uniqueStandardizedURLs(urls)
            guard !selected.isEmpty else { return }
            switch selectedTab {
            case .video:
                applyImportedSources(selected, accept: isVideoInputURL) { urls in
                    applySelectedVideoSources(urls)
                }
            case .image:
                applyImportedSources(selected, accept: isImageInputURL) { urls in
                    applySelectedImageSources(urls)
                }
            case .audio:
                applyImportedSources(selected, accept: isAudioInputURL) { urls in
                    applySelectedAudioSources(urls)
                }
            case .about:
                break
            }
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        handleVideoDrop(providers: providers)
    }

    func handleMediaDrop(
        providers: [NSItemProvider],
        accept: @escaping (URL) -> Bool,
        applySelection: @escaping @MainActor ([URL]) -> Void
    ) -> Bool {
        handleDroppedFiles(providers: providers, accept: accept, onResolvedURLs: applySelection)
    }

    func handleVideoDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isVideoInputURL) { [weak self] urls in
            self?.applySelectedVideoSources(urls)
        }
    }

    func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isImageInputURL) { [weak self] urls in
            self?.applySelectedImageSources(urls)
        }
    }

    func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isAudioInputURL) { [weak self] urls in
            self?.applySelectedAudioSources(urls)
        }
    }

    func handleDroppedFiles(
        providers: [NSItemProvider],
        accept: @escaping (URL) -> Bool,
        onResolvedURLs: @escaping @MainActor ([URL]) -> Void
    ) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var resolvedURLs: [URL] = []

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                var finalURL: URL?

                if let data = item as? Data {
                    finalURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    finalURL = url
                }

                guard let finalURL else { return }

                lock.lock()
                resolvedURLs.append(finalURL)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let unique = self.uniqueStandardizedURLs(resolvedURLs)
            let accepted = unique.filter(accept)
            guard !accepted.isEmpty else { return }

            Task { @MainActor in
                onResolvedURLs(accepted)
            }
        }

        return true
    }

    func moveSelectedVideoSource(from draggedURL: URL, to targetURL: URL) {
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isConverting,
            currentPrimaryURL: sourceURL,
            selectedSourceURLs: selectedVideoSourceURLs,
            assignSelection: { reordered in
                assignVideoSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&sourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetVideoCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredVideoSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeSourceCompatibility(for: urls)
            }
        )
    }

    func moveSelectedImageSource(from draggedURL: URL, to targetURL: URL) {
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isImageConverting,
            currentPrimaryURL: imageSourceURL,
            selectedSourceURLs: selectedImageSourceURLs,
            assignSelection: { reordered in
                assignImageSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&imageSourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetImageCompatibilityState(resetMetadata: true)
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredImageSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeImageSourceCompatibility(for: urls)
            }
        )
    }

    func moveSelectedAudioSource(from draggedURL: URL, to targetURL: URL) {
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isAudioConverting,
            currentPrimaryURL: audioSourceURL,
            selectedSourceURLs: selectedAudioSourceURLs,
            assignSelection: { reordered in
                assignAudioSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&audioSourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetAudioCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredAudioSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeAudioSourceCompatibility(for: urls)
            }
        )
    }

    func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
    }

    func labeledCapabilityMessage(_ message: String, for sourceURL: URL, totalCount: Int) -> String {
        ContentViewModelSupport.labeledCapabilityMessage(message, for: sourceURL, totalCount: totalCount)
    }

    func joinedCapabilityMessages(_ messages: [String]) -> String? {
        ContentViewModelSupport.joinedCapabilityMessages(messages)
    }
}
