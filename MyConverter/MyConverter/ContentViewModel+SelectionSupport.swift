import Foundation

extension ConverterTab {
    var mediaKind: ContentViewModel.MediaKind? {
        ContentViewModel.MediaKind(rawValue: rawValue)
    }
}

extension ContentViewModel {
    private static let selectionAnalysisDebounceNanoseconds: UInt64 = 200_000_000

    struct MediaSelectionWorkflowDescriptor {
        let isConversionRunning: Bool
        let currentPrimaryURL: URL?
        let selectedSourceURLs: [URL]
        let assignSelection: ([URL]) -> Void
        let invalidatePreparedState: () -> Void
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

    func acceptedInputURLs(
        _ urls: [URL],
        accept: (URL) -> Bool
    ) -> [URL] {
        uniqueStandardizedURLs(urls).filter(accept)
    }

    func cancelTask(_ task: inout Task<Void, Never>?) {
        task?.cancel()
        task = nil
    }

    func pendingSelectionAnalysisTaskKeyPath(
        for kind: MediaKind
    ) -> ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?> {
        switch kind {
        case .video:
            return \.taskState.pendingVideoSelectionAnalysisTask
        case .image:
            return \.taskState.pendingImageSelectionAnalysisTask
        case .audio:
            return \.taskState.pendingAudioSelectionAnalysisTask
        }
    }

    func cancelPendingSelectionAnalysis(for kind: MediaKind) {
        cancelTask(at: pendingSelectionAnalysisTaskKeyPath(for: kind))
    }

    func cancelSelectionAnalysis(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        cancelTask(at: descriptor.analysisTask)
        cancelPendingSelectionAnalysis(for: kind)
    }

    func scheduleSelectedSourceAnalysis(_ urls: [URL], for kind: MediaKind) {
        let selection = uniqueStandardizedURLs(urls)
        guard !selection.isEmpty else {
            analyzeSelectedSources(selection, for: kind)
            return
        }

        let descriptor = mediaStateDescriptor(for: kind)
        setMediaStateValue(using: descriptor, \.isAnalyzing, to: true)
        applyPlaceholderCapabilities(for: kind)
        scheduleDebouncedTask(
            pendingSelectionAnalysisTaskKeyPath(for: kind),
            delayNanoseconds: Self.selectionAnalysisDebounceNanoseconds
        ) { viewModel in
            viewModel.analyzeSelectedSources(selection, for: kind)
        }
    }

    func selectionWorkflowDescriptor(for kind: MediaKind) -> MediaSelectionWorkflowDescriptor {
        let descriptor = mediaStateDescriptor(for: kind)

        return MediaSelectionWorkflowDescriptor(
            isConversionRunning: mediaStateValue(using: descriptor, \.isConverting),
            currentPrimaryURL: mediaStateValue(using: descriptor, \.sourceURL),
            selectedSourceURLs: selectedSourceURLs(for: kind),
            assignSelection: { selection in
                self.assignSelection(selection, for: kind)
            },
            invalidatePreparedState: {
                self.clearPreparedSingleVideoSelection(for: kind)
            },
            cancelAnalysisTask: {
                self.cancelSelectionAnalysis(for: kind)
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
                self.scheduleSelectedSourceAnalysis(selection, for: kind)
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
        using workflow: MediaSelectionWorkflowDescriptor
    ) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let primaryURL = uniqueURLs.first else { return }

        workflow.invalidatePreparedState()
        workflow.cancelAnalysisTask()
        workflow.assignSelection(uniqueURLs)
        workflow.resetSelectionState()

        workflow.applyStoredSettingsForSourceID(sourceIdentifier(for: primaryURL))
        workflow.analyzeSelection(uniqueURLs)
    }

    func applySelectedSources(_ urls: [URL], for kind: MediaKind) {
        applySelectedSources(urls, using: selectionWorkflowDescriptor(for: kind))
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

    func refreshSelectionAfterPrimarySourceChange(
        _ urls: [URL],
        using workflow: MediaSelectionWorkflowDescriptor
    ) {
        guard let primaryURL = urls.first else { return }

        let primarySourceID = sourceIdentifier(for: primaryURL)
        guard workflow.currentPrimaryURL.map(sourceIdentifier(for:)) != primarySourceID else {
            return
        }

        workflow.invalidatePreparedState()
        workflow.cancelAnalysisTask()
        workflow.resetCompatibilityState()
        workflow.applyStoredSettingsForSourceID(primarySourceID)
        workflow.analyzeSelection(urls)
    }

    func removeProcessedSource(
        _ processedURL: URL,
        using workflow: MediaSelectionWorkflowDescriptor
    ) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = workflow.selectedSourceURLs.filter { sourceIdentifier(for: $0) != processedID }
        workflow.assignSelection(remainingSources)
        guard !remainingSources.isEmpty else {
            workflow.onSelectionEmptied()
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
