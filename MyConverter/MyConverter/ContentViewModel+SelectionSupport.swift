import Foundation

extension ConverterTab {
    var mediaKind: ContentViewModel.MediaKind? {
        ContentViewModel.MediaKind(rawValue: rawValue)
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

    func selectionWorkflowDescriptor(for kind: MediaKind) -> MediaSelectionWorkflowDescriptor {
        let descriptor = mediaStateDescriptor(for: kind)

        return MediaSelectionWorkflowDescriptor(
            isConversionRunning: mediaStateValue(using: descriptor, \.isConverting),
            currentPrimaryURL: mediaStateValue(using: descriptor, \.sourceURL),
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
        using workflow: MediaSelectionWorkflowDescriptor
    ) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let primaryURL = uniqueURLs.first else { return }

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
