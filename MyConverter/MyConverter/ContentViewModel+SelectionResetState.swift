import Foundation

extension ContentViewModel.MediaKind {
    func resetConversionOutputs(in viewModel: ContentViewModel) {
        setConvertedURL(nil, in: viewModel)
        setConvertedURLs([], in: viewModel)
        setConvertedOutputURLsBySourceID([:], in: viewModel)
        setProcessedSourceIDs([], in: viewModel)
        setConversionErrorMessage(nil, in: viewModel)
    }

    func resetCompatibilityState(
        in viewModel: ContentViewModel,
        resetMetadata: Bool = true
    ) {
        if resetMetadata {
            resetCompatibilityMetadata(in: viewModel)
        }

        setCompatibilityMessages(
            warningMessage: nil,
            errorMessage: nil,
            in: viewModel
        )
    }

    func resetSelectionCompatibilityState(in viewModel: ContentViewModel) {
        resetCompatibilityState(in: viewModel)
    }

    private func clearActivityState(
        in viewModel: ContentViewModel,
        resetBatchState: Bool
    ) {
        setAnalyzing(false, in: viewModel)

        guard resetBatchState else { return }
        setCurrentBatchIndex(0, in: viewModel)
        setTotalBatchCount(0, in: viewModel)
    }

    func restoreIdleState(
        in viewModel: ContentViewModel,
        resetOutputs: Bool = false,
        resetBatchState: Bool = false,
        applyDefaultSettings: Bool = false
    ) {
        clearPreparedSingleVideoSelection(in: viewModel)
        cancelSelectionAnalysis(in: viewModel)

        if resetOutputs {
            resetConversionOutputs(in: viewModel)
        }

        resetCompatibilityState(in: viewModel)
        clearActivityState(in: viewModel, resetBatchState: resetBatchState)

        applyPlaceholderCapabilities(to: viewModel)

        if applyDefaultSettings {
            applyDefaultSourceSettings(to: viewModel)
        }

        markCapabilityBootstrapNeedsRefresh(in: viewModel)
        scheduleCapabilityBootstrap(in: viewModel)
    }

    func clearSelectedSource(in viewModel: ContentViewModel) {
        clearPreparedSingleVideoSelection(in: viewModel)
        cancelSelectionAnalysis(in: viewModel)
        assignSelection([], in: viewModel)
        restoreIdleState(
            in: viewModel,
            resetOutputs: true,
            resetBatchState: true,
            applyDefaultSettings: true
        )
    }
}
