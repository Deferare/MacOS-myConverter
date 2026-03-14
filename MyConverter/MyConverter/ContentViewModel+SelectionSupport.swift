import Foundation

extension ConverterTab {
    var mediaKind: ContentViewModel.MediaKind? {
        ContentViewModel.MediaKind(rawValue: rawValue)
    }
}

extension ContentViewModel {
    private static let selectionAnalysisDebounceNanoseconds: UInt64 = 200_000_000

    func cancelTask(_ task: inout Task<Void, Never>?) {
        task?.cancel()
        task = nil
    }

    func cancelPendingSelectionAnalysis(for kind: MediaKind) {
        let descriptor = kind.mediaStateDescriptor
        cancelTask(at: descriptor.pendingSelectionAnalysisTask)
    }

    func cancelSelectionAnalysis(for kind: MediaKind) {
        let descriptor = kind.mediaStateDescriptor
        cancelTask(at: descriptor.analysisTask)
        cancelPendingSelectionAnalysis(for: kind)
    }

    func scheduleSelectedSourceAnalysis(_ urls: [URL], for kind: MediaKind) {
        let selection = ContentViewModelSupport.uniqueStandardizedURLs(urls)
        guard !selection.isEmpty else {
            analyzeSelectedSources(selection, for: kind)
            return
        }

        let descriptor = kind.mediaStateDescriptor
        self[keyPath: descriptor.isAnalyzing] = true
        kind.applyPlaceholderCapabilities(to: self)
        scheduleDebouncedTask(
            descriptor.pendingSelectionAnalysisTask,
            delayNanoseconds: Self.selectionAnalysisDebounceNanoseconds
        ) { viewModel in
            viewModel.analyzeSelectedSources(selection, for: kind)
        }
    }

    func assignPrimaryAndQueuedSources(
        _ urls: [URL],
        primaryKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        queuedKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>
    ) {
        self[keyPath: primaryKeyPath] = urls.first
        self[keyPath: queuedKeyPath] = Array(urls.dropFirst())
    }

    func applySelectedSources(_ urls: [URL], for kind: MediaKind) {
        let uniqueURLs = ContentViewModelSupport.uniqueStandardizedURLs(urls)
        guard let primaryURL = uniqueURLs.first else { return }

        clearPreparedSingleVideoSelection(for: kind)
        cancelSelectionAnalysis(for: kind)
        assignSelection(uniqueURLs, for: kind)
        resetConversionOutputs(for: kind)
        resetSelectionCompatibilityState(for: kind)
        kind.applyStoredSourceSettings(
            sourceID: sourceIdentifier(for: primaryURL),
            to: self
        )
        scheduleSelectedSourceAnalysis(uniqueURLs, for: kind)
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

    func refreshSelectionAfterPrimarySourceChange(_ urls: [URL], for kind: MediaKind) {
        guard let primaryURL = urls.first else { return }

        let primarySourceID = sourceIdentifier(for: primaryURL)
        let descriptor = kind.mediaStateDescriptor
        guard self[keyPath: descriptor.sourceURL].map(sourceIdentifier(for:)) != primarySourceID else {
            return
        }

        clearPreparedSingleVideoSelection(for: kind)
        cancelSelectionAnalysis(for: kind)
        resetSelectionCompatibilityState(for: kind)
        kind.applyStoredSourceSettings(sourceID: primarySourceID, to: self)
        scheduleSelectedSourceAnalysis(urls, for: kind)
    }

    func removeProcessedSource(_ processedURL: URL, for kind: MediaKind) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = mediaStateSnapshot(for: kind)
            .selectedSourceURLs
            .filter { sourceIdentifier(for: $0) != processedID }
        assignSelection(remainingSources, for: kind)
        guard !remainingSources.isEmpty else {
            restoreIdleMediaState(for: kind)
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
