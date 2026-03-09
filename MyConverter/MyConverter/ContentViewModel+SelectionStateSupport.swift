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

    struct SelectedFileListState {
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

    func selectedFileListState(for kind: MediaKind) -> SelectedFileListState {
        let snapshot = mediaStateSnapshot(for: kind)

        return SelectedFileListState(
            selectedURLs: selectedSourceURLs(using: snapshot),
            outputURLsBySourceID: snapshot.convertedOutputURLsBySourceID,
            processedSourceIDs: snapshot.processedSourceIDs,
            isConverting: snapshot.isConverting,
            currentBatchIndex: snapshot.currentBatchIndex,
            currentItemProgress: currentBatchItemProgress(using: snapshot)
        )
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
        let descriptor = mediaStateDescriptor(for: kind)

        if resetOutputs {
            resetConversionOutputs(for: kind)
        }

        resetCompatibilityState(for: kind)
        setMediaStateValue(using: descriptor, \.isAnalyzing, to: false)

        if resetBatchState {
            setMediaStateValue(using: descriptor, \.currentBatchIndex, to: 0)
            setMediaStateValue(using: descriptor, \.totalBatchCount, to: 0)
        }

        applyPlaceholderCapabilities(for: kind)

        if applyDefaultSettings {
            applyDefaultSourceSettings(for: kind)
        }

        scheduleCapabilityBootstrap(for: kind)
    }

    func clearSelectedSource(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)

        cancelTask(at: descriptor.analysisTask)
        setMediaStateValue(using: descriptor, \.sourceURL, to: nil)
        setMediaStateValue(using: descriptor, \.queuedSourceURLs, to: [])
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
}
