import Foundation

extension ContentViewModel {
    func mediaKind(for tab: ConverterTab) -> MediaKind? {
        switch tab {
        case .video:
            return .video
        case .image:
            return .image
        case .audio:
            return .audio
        case .about:
            return nil
        }
    }

    func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        ContentViewModelSupport.uniqueStandardizedURLs(urls)
    }

    func acceptsInput(_ url: URL, for kind: MediaKind) -> Bool {
        switch kind {
        case .video:
            return isVideoInputURL(url)
        case .image:
            return isImageInputURL(url)
        case .audio:
            return isAudioInputURL(url)
        }
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

    func applySelectedSources(_ urls: [URL], for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)

        applySelectedSources(
            urls,
            cancelAnalysisTask: {
                cancelTask(at: descriptor.analysisTask)
            },
            assignSelection: { selection in
                assignSelection(selection, for: kind)
            },
            resetState: {
                resetSelectionStateForSelectedSources(for: kind)
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredSettings(for: kind, sourceID: sourceID)
            },
            analyzeSelection: { selection in
                reanalyzeSelection(selection, for: kind)
            }
        )
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

    func labeledCapabilityMessage(_ message: String, for sourceURL: URL, totalCount: Int) -> String {
        ContentViewModelSupport.labeledCapabilityMessage(message, for: sourceURL, totalCount: totalCount)
    }

    func joinedCapabilityMessages(_ messages: [String]) -> String? {
        ContentViewModelSupport.joinedCapabilityMessages(messages)
    }

    func resetSelectionStateForSelectedSources(for kind: MediaKind) {
        resetConversionOutputs(for: kind)
        resetCompatibilityStateForSelectionChange(for: kind)
    }
}
