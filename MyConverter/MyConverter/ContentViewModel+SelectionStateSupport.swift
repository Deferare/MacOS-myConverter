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

        var inputSystemImage: String {
            descriptor.usesFilledInputSystemImage
                ? "\(sidebarSystemImage).fill"
                : sidebarSystemImage
        }
    }

    struct SelectedFileListState: Equatable {
        let selectedURLs: [URL]
        let outputURLsBySourceID: [String: URL]
        let processedSourceIDs: Set<String>
        let isConverting: Bool
        let currentBatchIndex: Int
        let currentItemProgress: Double
    }

    func selectedSourceURLs(using snapshot: MediaStateSnapshot) -> [URL] {
        guard let sourceURL = snapshot.sourceURL else { return [] }
        return [sourceURL] + snapshot.queuedSourceURLs
    }

    func selectedSourceURLs(for kind: MediaKind) -> [URL] {
        selectedSourceURLs(using: mediaStateSnapshot(for: kind))
    }

    func selectedFileCount(for kind: MediaKind) -> Int {
        let snapshot = mediaStateSnapshot(for: kind)
        guard snapshot.sourceURL != nil else { return 0 }
        return snapshot.queuedSourceURLs.count + 1
    }

    func displayedProgress(for snapshot: MediaStateSnapshot) -> Double {
        return displayedProgress(
            isConverting: snapshot.isConverting,
            rawProgress: snapshot.progress
        )
    }

    func displayedProgress(for kind: MediaKind) -> Double {
        displayedProgress(for: mediaStateSnapshot(for: kind))
    }

    func selectedFileListState(using snapshot: MediaStateSnapshot) -> SelectedFileListState {
        SelectedFileListState(
            selectedURLs: selectedSourceURLs(using: snapshot),
            outputURLsBySourceID: snapshot.convertedOutputURLsBySourceID,
            processedSourceIDs: snapshot.processedSourceIDs,
            isConverting: snapshot.isConverting,
            currentBatchIndex: snapshot.currentBatchIndex,
            currentItemProgress: currentBatchItemProgress(using: snapshot)
        )
    }

    func selectedFileListState(for kind: MediaKind) -> SelectedFileListState {
        selectedFileListState(using: mediaStateSnapshot(for: kind))
    }

    func currentBatchItemProgress(using snapshot: MediaStateSnapshot) -> Double {
        guard snapshot.isConverting,
              snapshot.currentBatchIndex > 0,
              snapshot.totalBatchCount > 0 else {
            return 0
        }

        let completedBatchCount = Double(snapshot.currentBatchIndex - 1)
        let totalBatchCount = Double(max(snapshot.totalBatchCount, 1))
        let itemProgress = (snapshot.progress * totalBatchCount) - completedBatchCount
        return clampedProgress(itemProgress)
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
        switch kind {
        case .video:
            updateState(\.videoRuntimeState) { state in
                state.media.isAnalyzingSource = false
                if resetBatchState {
                    state.media.currentBatchIndex = 0
                    state.media.totalBatchCount = 0
                }
            }
        case .image:
            updateState(\.imageRuntimeState) { state in
                state.media.isAnalyzingSource = false
                if resetBatchState {
                    state.media.currentBatchIndex = 0
                    state.media.totalBatchCount = 0
                }
            }
        case .audio:
            updateState(\.audioRuntimeState) { state in
                state.media.isAnalyzingSource = false
                if resetBatchState {
                    state.media.currentBatchIndex = 0
                    state.media.totalBatchCount = 0
                }
            }
        }

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
        switch kind {
        case .video:
            updateState(\.videoRuntimeState) { state in
                state.media.sourceURL = nil
                state.media.queuedSourceURLs = []
            }
        case .image:
            updateState(\.imageRuntimeState) { state in
                state.media.sourceURL = nil
                state.media.queuedSourceURLs = []
            }
        case .audio:
            updateState(\.audioRuntimeState) { state in
                state.media.sourceURL = nil
                state.media.queuedSourceURLs = []
            }
        }
        restoreIdleMediaState(
            for: kind,
            resetOutputs: true,
            resetBatchState: true,
            applyDefaultSettings: true
        )
    }

    func resetConversionOutputs(for kind: MediaKind) {
        switch kind {
        case .video:
            updateState(\.videoRuntimeState) { state in
                state.media.convertedURL = nil
                state.media.convertedURLs = []
                state.media.convertedOutputURLsBySourceID = [:]
                state.media.processedSourceIDs = []
                state.media.conversionErrorMessage = nil
            }
        case .image:
            updateState(\.imageRuntimeState) { state in
                state.media.convertedURL = nil
                state.media.convertedURLs = []
                state.media.convertedOutputURLsBySourceID = [:]
                state.media.processedSourceIDs = []
                state.media.conversionErrorMessage = nil
            }
        case .audio:
            updateState(\.audioRuntimeState) { state in
                state.media.convertedURL = nil
                state.media.convertedURLs = []
                state.media.convertedOutputURLsBySourceID = [:]
                state.media.processedSourceIDs = []
                state.media.conversionErrorMessage = nil
            }
        }
    }

    func resetCompatibilityState(for kind: MediaKind, resetMetadata: Bool = true) {
        if resetMetadata {
            mediaStateDescriptor(for: kind).resetCompatibilityMetadata(self)
        }

        switch kind {
        case .video:
            updateState(\.videoRuntimeState) { state in
                state.media.sourceCompatibilityErrorMessage = nil
                state.media.sourceCompatibilityWarningMessage = nil
            }
        case .image:
            updateState(\.imageRuntimeState) { state in
                state.media.sourceCompatibilityErrorMessage = nil
                state.media.sourceCompatibilityWarningMessage = nil
            }
        case .audio:
            updateState(\.audioRuntimeState) { state in
                state.media.sourceCompatibilityErrorMessage = nil
                state.media.sourceCompatibilityWarningMessage = nil
            }
        }
    }

    func resetSelectionCompatibilityState(for kind: MediaKind) {
        resetCompatibilityState(for: kind)
    }
}
