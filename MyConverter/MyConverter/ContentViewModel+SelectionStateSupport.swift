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

    func resetConversionOutputs(for kind: MediaKind) {
        let descriptor = kind.mediaStateDescriptor
        self[keyPath: descriptor.convertedURL] = nil
        self[keyPath: descriptor.convertedURLs] = []
        self[keyPath: descriptor.convertedOutputURLsBySourceID] = [:]
        self[keyPath: descriptor.processedSourceIDs] = []
        self[keyPath: descriptor.conversionErrorMessage] = nil
    }

    func resetCompatibilityState(for kind: MediaKind, resetMetadata: Bool = true) {
        if resetMetadata {
            resetCompatibilityMetadata(for: kind)
        }

        let descriptor = kind.mediaStateDescriptor
        self[keyPath: descriptor.compatibilityErrorMessage] = nil
        self[keyPath: descriptor.compatibilityWarningMessage] = nil
    }

    func resetSelectionCompatibilityState(for kind: MediaKind) {
        resetCompatibilityState(for: kind)
    }

    private func clearActivityState(for kind: MediaKind, resetBatchState: Bool) {
        let descriptor = kind.mediaStateDescriptor
        self[keyPath: descriptor.isAnalyzing] = false

        guard resetBatchState else { return }
        self[keyPath: descriptor.currentBatchIndex] = 0
        self[keyPath: descriptor.totalBatchCount] = 0
    }
}

extension ContentViewModel.MediaKind {
    func restoreIdleState(
        in viewModel: ContentViewModel,
        resetOutputs: Bool = false,
        resetBatchState: Bool = false,
        applyDefaultSettings: Bool = false
    ) {
        viewModel.clearPreparedSingleVideoSelection(for: self)
        viewModel.cancelSelectionAnalysis(for: self)

        if resetOutputs {
            viewModel.resetConversionOutputs(for: self)
        }

        viewModel.resetCompatibilityState(for: self)
        viewModel.clearActivityState(for: self, resetBatchState: resetBatchState)

        applyPlaceholderCapabilities(to: viewModel)

        if applyDefaultSettings {
            applyDefaultSourceSettings(to: viewModel)
        }

        viewModel.markCapabilityBootstrapNeedsRefresh(for: [self])
        viewModel.scheduleCapabilityBootstrap(for: self)
    }

    func clearSelectedSource(in viewModel: ContentViewModel) {
        viewModel.clearPreparedSingleVideoSelection(for: self)
        viewModel.cancelSelectionAnalysis(for: self)
        viewModel.assignSelection([], for: self)
        restoreIdleState(
            in: viewModel,
            resetOutputs: true,
            resetBatchState: true,
            applyDefaultSettings: true
        )
    }
}
