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
        let outputURLs: [URL]
        let isConverting: Bool
        let currentBatchIndex: Int
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
            outputURLs: snapshot.convertedURLs,
            isConverting: snapshot.isConverting,
            currentBatchIndex: snapshot.currentBatchIndex
        )
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
        self[keyPath: descriptor.isAnalyzing] = false

        if resetBatchState {
            self[keyPath: descriptor.currentBatchIndex] = 0
            self[keyPath: descriptor.totalBatchCount] = 0
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
        self[keyPath: descriptor.sourceURL] = nil
        self[keyPath: descriptor.queuedSourceURLs] = []
        restoreIdleMediaState(
            for: kind,
            resetOutputs: true,
            resetBatchState: true,
            applyDefaultSettings: true
        )
    }

    func resetConversionOutputs(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        self[keyPath: descriptor.convertedURL] = nil
        self[keyPath: descriptor.convertedURLs] = []
        self[keyPath: descriptor.conversionErrorMessage] = nil
    }

    func resetCompatibilityState(for kind: MediaKind, resetMetadata: Bool = true) {
        let descriptor = mediaStateDescriptor(for: kind)

        if resetMetadata {
            descriptor.resetCompatibilityMetadata(self)
        }

        self[keyPath: descriptor.compatibilityErrorMessage] = nil
        self[keyPath: descriptor.compatibilityWarningMessage] = nil
    }

    func resetSelectionCompatibilityState(for kind: MediaKind) {
        resetCompatibilityState(for: kind)
    }
}
