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

    func applyStoredSettingsForSource<Settings>(
        sourceID: String,
        settingsBySourceID: [String: Settings],
        defaultSettings: @autoclosure () -> Settings,
        apply: (Settings) -> Void
    ) {
        let stored = settingsBySourceID[sourceID] ?? defaultSettings()
        apply(stored)
    }
}

extension ContentViewModel.MediaKind {
    func scheduleSelectedSourceAnalysis(_ urls: [URL], in viewModel: ContentViewModel) {
        let selection = ContentViewModelSupport.uniqueStandardizedURLs(urls)
        guard !selection.isEmpty else {
            analyzeSelectedSources(selection, in: viewModel)
            return
        }

        setAnalyzing(true, in: viewModel)
        applyPlaceholderCapabilities(to: viewModel)
        viewModel.scheduleDebouncedTask(
            pendingSelectionAnalysisTaskKeyPath,
            delayNanoseconds: ContentViewModel.selectionAnalysisDebounceNanoseconds
        ) { viewModel in
            self.analyzeSelectedSources(selection, in: viewModel)
        }
    }

    func applySelectedSources(_ urls: [URL], in viewModel: ContentViewModel) {
        let uniqueURLs = ContentViewModelSupport.uniqueStandardizedURLs(urls)
        guard let primaryURL = uniqueURLs.first else { return }

        clearPreparedSingleVideoSelection(in: viewModel)
        cancelSelectionAnalysis(in: viewModel)
        assignSelection(uniqueURLs, in: viewModel)
        resetConversionOutputs(in: viewModel)
        resetSelectionCompatibilityState(in: viewModel)
        applyStoredSourceSettings(
            sourceID: viewModel.sourceIdentifier(for: primaryURL),
            to: viewModel
        )
        scheduleSelectedSourceAnalysis(uniqueURLs, in: viewModel)
    }

    func refreshSelectionAfterPrimarySourceChange(_ urls: [URL], in viewModel: ContentViewModel) {
        guard let primaryURL = urls.first else { return }

        let primarySourceID = viewModel.sourceIdentifier(for: primaryURL)
        guard sourceURL(in: viewModel).map(viewModel.sourceIdentifier(for:)) != primarySourceID else {
            return
        }

        clearPreparedSingleVideoSelection(in: viewModel)
        cancelSelectionAnalysis(in: viewModel)
        resetSelectionCompatibilityState(in: viewModel)
        applyStoredSourceSettings(sourceID: primarySourceID, to: viewModel)
        scheduleSelectedSourceAnalysis(urls, in: viewModel)
    }

    func cancelPendingSelectionAnalysis(in viewModel: ContentViewModel) {
        viewModel.cancelTask(at: mediaStateDescriptor.pendingSelectionAnalysisTask)
    }

    func cancelSelectionAnalysis(in viewModel: ContentViewModel) {
        viewModel.cancelTask(at: mediaStateDescriptor.analysisTask)
        cancelPendingSelectionAnalysis(in: viewModel)
    }
}
