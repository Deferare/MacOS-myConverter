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

        var sidebarSystemImage: String {
            descriptor.sidebarSystemImage
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

    func restoreIdleMediaState(
        for kind: MediaKind,
        resetOutputs: Bool = false,
        resetBatchState: Bool = false,
        applyDefaultSettings: Bool = false
    ) {
        clearPreparedSingleVideoSelection(for: kind)
        cancelSelectionAnalysis(for: kind)

        if resetOutputs {
            resetConversionOutputs(for: kind)
        }

        resetCompatibilityState(for: kind)
        clearActivityState(for: kind, resetBatchState: resetBatchState)

        applyPlaceholderCapabilities(for: kind)

        if applyDefaultSettings {
            applyDefaultSourceSettings(for: kind)
        }

        markCapabilityBootstrapNeedsRefresh(for: [kind])
        scheduleCapabilityBootstrap(for: kind)
    }

    func clearSelectedSource(for kind: MediaKind) {
        clearPreparedSingleVideoSelection(for: kind)
        cancelSelectionAnalysis(for: kind)
        assignSelection([], for: kind)
        restoreIdleMediaState(
            for: kind,
            resetOutputs: true,
            resetBatchState: true,
            applyDefaultSettings: true
        )
    }

    func resetConversionOutputs(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        setMediaStateValue(using: descriptor, \.convertedURL, to: nil)
        setMediaStateValue(using: descriptor, \.convertedURLs, to: [])
        setMediaStateValue(using: descriptor, \.convertedOutputURLsBySourceID, to: [:])
        setMediaStateValue(using: descriptor, \.processedSourceIDs, to: [])
        setMediaStateValue(using: descriptor, \.conversionErrorMessage, to: nil)
    }

    func resetCompatibilityState(for kind: MediaKind, resetMetadata: Bool = true) {
        let descriptor = mediaStateDescriptor(for: kind)
        if resetMetadata {
            descriptor.resetCompatibilityMetadata(self)
        }

        setMediaStateValue(using: descriptor, \.compatibilityErrorMessage, to: nil)
        setMediaStateValue(using: descriptor, \.compatibilityWarningMessage, to: nil)
    }

    func resetSelectionCompatibilityState(for kind: MediaKind) {
        resetCompatibilityState(for: kind)
    }

    private func clearActivityState(for kind: MediaKind, resetBatchState: Bool) {
        let descriptor = mediaStateDescriptor(for: kind)
        setMediaStateValue(using: descriptor, \.isAnalyzing, to: false)

        guard resetBatchState else { return }
        setMediaStateValue(using: descriptor, \.currentBatchIndex, to: 0)
        setMediaStateValue(using: descriptor, \.totalBatchCount, to: 0)
    }
}
