import Foundation

extension ContentViewModel {
    enum MediaKind: String, Equatable, Hashable, Sendable, CaseIterable {
        case video
        case image
        case audio

        var sidebarTitle: String {
            rawValue.capitalized
        }

        var converterTitle: String {
            "Convert \(sidebarTitle)"
        }
    }

    struct SelectedFileListState: Equatable {
        enum RowStatus: Equatable {
            case pending
            case converting(progress: Double)
            case completed(URL)
            case skipped
        }

        let selectedURLs: [URL]
        let outputURLsBySourceID: [String: URL]
        let processedSourceIDs: Set<String>
        let isConverting: Bool
        let currentBatchIndex: Int
        let currentItemProgress: Double

        init(
            selectedURLs: [URL],
            outputURLsBySourceID: [String: URL],
            processedSourceIDs: Set<String>,
            isConverting: Bool,
            currentBatchIndex: Int,
            currentItemProgress: Double
        ) {
            self.selectedURLs = selectedURLs
            self.outputURLsBySourceID = outputURLsBySourceID
            self.processedSourceIDs = processedSourceIDs
            self.isConverting = isConverting
            self.currentBatchIndex = currentBatchIndex
            self.currentItemProgress = currentItemProgress
        }

        func rowStatus(for url: URL) -> RowStatus {
            rowStatus(forSourceID: ContentViewModelSupport.sourceIdentifier(for: url))
        }

        func rowStatus(forSourceID sourceID: String) -> RowStatus {
            if let outputURL = outputURLsBySourceID[sourceID] {
                return .completed(outputURL)
            }

            if isConverting, sourceID == currentConvertingSourceID {
                return .converting(progress: currentItemProgress)
            }

            if processedSourceIDs.contains(sourceID) {
                return .skipped
            }

            return .pending
        }

        private var currentConvertingSourceID: String? {
            guard isConverting, currentBatchIndex > 0 else {
                return nil
            }

            let completedBeforeCurrentRunSourceIDs = Set(outputURLsBySourceID.keys)
                .subtracting(processedSourceIDs)
            let activeBatchSourceURLs = selectedURLs.filter { sourceURL in
                !completedBeforeCurrentRunSourceIDs.contains(
                    ContentViewModelSupport.sourceIdentifier(for: sourceURL)
                )
            }

            let remainingIndex = currentBatchIndex - 1
            guard activeBatchSourceURLs.indices.contains(remainingIndex) else {
                return nil
            }

            return ContentViewModelSupport.sourceIdentifier(for: activeBatchSourceURLs[remainingIndex])
        }

        init(snapshot: ContentViewModel.MediaStateSnapshot) {
            self.init(
                selectedURLs: snapshot.selectedSourceURLs,
                outputURLsBySourceID: snapshot.convertedOutputURLsBySourceID,
                processedSourceIDs: snapshot.processedSourceIDs,
                isConverting: snapshot.isConverting,
                currentBatchIndex: snapshot.currentBatchIndex,
                currentItemProgress: snapshot.currentBatchItemProgress
            )
        }
    }

    func cancelTask(at keyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>) {
        self[keyPath: keyPath]?.cancel()
        self[keyPath: keyPath] = nil
    }

}

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
        viewModel.clearPreparedSingleVideoSelection(for: self)
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

        viewModel.markCapabilityBootstrapNeedsRefresh(for: [self])
        viewModel.scheduleCapabilityBootstrap(for: self)
    }

    func clearSelectedSource(in viewModel: ContentViewModel) {
        viewModel.clearPreparedSingleVideoSelection(for: self)
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
