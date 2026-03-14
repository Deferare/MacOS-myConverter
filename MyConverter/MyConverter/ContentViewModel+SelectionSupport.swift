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

    func scheduleSelectedSourceAnalysis(_ urls: [URL], for kind: MediaKind) {
        let selection = ContentViewModelSupport.uniqueStandardizedURLs(urls)
        guard !selection.isEmpty else {
            kind.analyzeSelectedSources(selection, in: self)
            return
        }

        kind.setAnalyzing(true, in: self)
        kind.applyPlaceholderCapabilities(to: self)
        scheduleDebouncedTask(
            kind.pendingSelectionAnalysisTaskKeyPath,
            delayNanoseconds: Self.selectionAnalysisDebounceNanoseconds
        ) { viewModel in
            kind.analyzeSelectedSources(selection, in: viewModel)
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
        kind.cancelSelectionAnalysis(in: self)
        kind.assignSelection(uniqueURLs, in: self)
        kind.resetConversionOutputs(in: self)
        kind.resetSelectionCompatibilityState(in: self)
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
        guard kind.sourceURL(in: self).map(sourceIdentifier(for:)) != primarySourceID else {
            return
        }

        clearPreparedSingleVideoSelection(for: kind)
        kind.cancelSelectionAnalysis(in: self)
        kind.resetSelectionCompatibilityState(in: self)
        kind.applyStoredSourceSettings(sourceID: primarySourceID, to: self)
        scheduleSelectedSourceAnalysis(urls, for: kind)
    }

    func removeProcessedSource(_ processedURL: URL, for kind: MediaKind) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = kind.mediaStateSnapshot(in: self)
            .selectedSourceURLs
            .filter { sourceIdentifier(for: $0) != processedID }
        kind.assignSelection(remainingSources, in: self)
        guard !remainingSources.isEmpty else {
            kind.restoreIdleState(in: self)
            return
        }
    }

}

extension ContentViewModel.MediaKind {
    func cancelPendingSelectionAnalysis(in viewModel: ContentViewModel) {
        viewModel.cancelTask(at: mediaStateDescriptor.pendingSelectionAnalysisTask)
    }

    func cancelSelectionAnalysis(in viewModel: ContentViewModel) {
        viewModel.cancelTask(at: mediaStateDescriptor.analysisTask)
        cancelPendingSelectionAnalysis(in: viewModel)
    }
}
