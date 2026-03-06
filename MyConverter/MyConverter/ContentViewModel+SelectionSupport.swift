import Foundation

extension ContentViewModel.MediaKind {
    func acceptsInput(_ url: URL) -> Bool {
        switch self {
        case .video:
            return ContentViewModelSupport.isVideoInputURL(url)
        case .image:
            return ContentViewModelSupport.isImageInputURL(url)
        case .audio:
            return ContentViewModelSupport.isAudioInputURL(url)
        }
    }
}

extension ConverterTab {
    var mediaKind: ContentViewModel.MediaKind? {
        switch self {
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
}

extension ContentViewModel {
    struct MediaSelectionWorkflowDescriptor {
        let isConversionRunning: Bool
        let currentPrimaryURL: URL?
        let selectedSourceURLs: [URL]
        let assignSelection: ([URL]) -> Void
        let cancelAnalysisTask: () -> Void
        let resetSelectionState: () -> Void
        let resetCompatibilityState: () -> Void
        let applyStoredSettingsForSourceID: (String) -> Void
        let analyzeSelection: ([URL]) -> Void
        let onSelectionEmptied: () -> Void
    }

    func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        ContentViewModelSupport.uniqueStandardizedURLs(urls)
    }

    func cancelTask(_ task: inout Task<Void, Never>?) {
        task?.cancel()
        task = nil
    }

    func selectionWorkflowDescriptor(for kind: MediaKind) -> MediaSelectionWorkflowDescriptor {
        let descriptor = mediaStateDescriptor(for: kind)

        return MediaSelectionWorkflowDescriptor(
            isConversionRunning: self[keyPath: descriptor.isConverting],
            currentPrimaryURL: self[keyPath: descriptor.sourceURL],
            selectedSourceURLs: selectedSourceURLs(for: kind),
            assignSelection: { selection in
                self.assignSelection(selection, for: kind)
            },
            cancelAnalysisTask: {
                self.cancelTask(at: descriptor.analysisTask)
            },
            resetSelectionState: {
                self.resetConversionOutputs(for: kind)
                self.resetSelectionCompatibilityState(for: kind)
            },
            resetCompatibilityState: {
                self.resetSelectionCompatibilityState(for: kind)
            },
            applyStoredSettingsForSourceID: { sourceID in
                self.applyStoredSourceSettings(for: sourceID, for: kind)
            },
            analyzeSelection: { selection in
                self.analyzeSelectedSources(selection, for: kind)
            },
            onSelectionEmptied: {
                self.restoreIdleMediaState(for: kind)
            }
        )
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
        let workflow = selectionWorkflowDescriptor(for: kind)

        applySelectedSources(
            urls,
            cancelAnalysisTask: workflow.cancelAnalysisTask,
            assignSelection: workflow.assignSelection,
            resetState: workflow.resetSelectionState,
            applyStoredSettingsForSourceID: workflow.applyStoredSettingsForSourceID,
            analyzeSelection: workflow.analyzeSelection
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
}
