import Foundation

extension ContentViewModel {
    enum MediaKind: Equatable, Sendable, CaseIterable {
        case video
        case image
        case audio

        var converterTitle: String {
            switch self {
            case .video:
                return "Convert Video"
            case .image:
                return "Convert Image"
            case .audio:
                return "Convert Audio"
            }
        }

        var inputSystemImage: String {
            switch self {
            case .video:
                return "film.fill"
            case .image:
                return "photo.fill"
            case .audio:
                return "waveform"
            }
        }
    }

    struct SelectedFileListState {
        let selectedURLs: [URL]
        let outputURLs: [URL]
        let isConverting: Bool
        let currentBatchIndex: Int
    }

    struct MediaStateDescriptor {
        let sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let queuedSourceURLs: ReferenceWritableKeyPath<ContentViewModel, [URL]>
        let convertedURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let convertedURLs: ReferenceWritableKeyPath<ContentViewModel, [URL]>
        let conversionErrorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let compatibilityErrorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let compatibilityWarningMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let isAnalyzing: ReferenceWritableKeyPath<ContentViewModel, Bool>
        let isConverting: ReferenceWritableKeyPath<ContentViewModel, Bool>
        let progress: ReferenceWritableKeyPath<ContentViewModel, Double>
        let currentBatchIndex: ReferenceWritableKeyPath<ContentViewModel, Int>
        let totalBatchCount: ReferenceWritableKeyPath<ContentViewModel, Int>
        let analysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let conversionTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
    }

    func mediaStateDescriptor(for kind: MediaKind) -> MediaStateDescriptor {
        switch kind {
        case .video:
            return MediaStateDescriptor(
                sourceURL: \.sourceURL,
                queuedSourceURLs: \.queuedSourceURLs,
                convertedURL: \.convertedURL,
                convertedURLs: \.convertedURLs,
                conversionErrorMessage: \.conversionErrorMessage,
                compatibilityErrorMessage: \.sourceCompatibilityErrorMessage,
                compatibilityWarningMessage: \.sourceCompatibilityWarningMessage,
                isAnalyzing: \.isAnalyzingSource,
                isConverting: \.isConverting,
                progress: \.conversionProgress,
                currentBatchIndex: \.currentVideoBatchIndex,
                totalBatchCount: \.totalVideoBatchCount,
                analysisTask: \.taskState.sourceAnalysisTask,
                conversionTask: \.taskState.conversionTask
            )
        case .image:
            return MediaStateDescriptor(
                sourceURL: \.imageSourceURL,
                queuedSourceURLs: \.queuedImageSourceURLs,
                convertedURL: \.convertedImageURL,
                convertedURLs: \.convertedImageURLs,
                conversionErrorMessage: \.imageConversionErrorMessage,
                compatibilityErrorMessage: \.imageSourceCompatibilityErrorMessage,
                compatibilityWarningMessage: \.imageSourceCompatibilityWarningMessage,
                isAnalyzing: \.isAnalyzingImageSource,
                isConverting: \.isImageConverting,
                progress: \.imageConversionProgress,
                currentBatchIndex: \.currentImageBatchIndex,
                totalBatchCount: \.totalImageBatchCount,
                analysisTask: \.taskState.imageSourceAnalysisTask,
                conversionTask: \.taskState.imageConversionTask
            )
        case .audio:
            return MediaStateDescriptor(
                sourceURL: \.audioSourceURL,
                queuedSourceURLs: \.queuedAudioSourceURLs,
                convertedURL: \.convertedAudioURL,
                convertedURLs: \.convertedAudioURLs,
                conversionErrorMessage: \.audioConversionErrorMessage,
                compatibilityErrorMessage: \.audioSourceCompatibilityErrorMessage,
                compatibilityWarningMessage: \.audioSourceCompatibilityWarningMessage,
                isAnalyzing: \.isAnalyzingAudioSource,
                isConverting: \.isAudioConverting,
                progress: \.audioConversionProgress,
                currentBatchIndex: \.currentAudioBatchIndex,
                totalBatchCount: \.totalAudioBatchCount,
                analysisTask: \.taskState.audioSourceAnalysisTask,
                conversionTask: \.taskState.audioConversionTask
            )
        }
    }

    func analyzeSelectedSources(_ urls: [URL], for kind: MediaKind) {
        switch kind {
        case .video:
            analyzeSourceCompatibility(for: urls, using: videoSourceAnalysisDescriptor())
        case .image:
            analyzeSourceCompatibility(for: urls, using: imageSourceAnalysisDescriptor())
        case .audio:
            analyzeSourceCompatibility(for: urls, using: audioSourceAnalysisDescriptor())
        }
    }

    func selectedSourceURLs(for kind: MediaKind) -> [URL] {
        let descriptor = mediaStateDescriptor(for: kind)
        guard let sourceURL = self[keyPath: descriptor.sourceURL] else { return [] }
        return [sourceURL] + self[keyPath: descriptor.queuedSourceURLs]
    }

    func selectedFileCount(for kind: MediaKind) -> Int {
        let descriptor = mediaStateDescriptor(for: kind)
        guard self[keyPath: descriptor.sourceURL] != nil else { return 0 }
        return self[keyPath: descriptor.queuedSourceURLs].count + 1
    }

    func displayedProgress(for kind: MediaKind) -> Double {
        let descriptor = mediaStateDescriptor(for: kind)
        return displayedProgress(
            isConverting: self[keyPath: descriptor.isConverting],
            rawProgress: self[keyPath: descriptor.progress]
        )
    }

    func selectedFileListState(for kind: MediaKind) -> SelectedFileListState {
        let descriptor = mediaStateDescriptor(for: kind)

        return SelectedFileListState(
            selectedURLs: selectedSourceURLs(for: kind),
            outputURLs: self[keyPath: descriptor.convertedURLs],
            isConverting: self[keyPath: descriptor.isConverting],
            currentBatchIndex: self[keyPath: descriptor.currentBatchIndex]
        )
    }

    func cancelTask(at keyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>) {
        self[keyPath: keyPath]?.cancel()
        self[keyPath: keyPath] = nil
    }

    func clearSelectedSourceState(
        cancelAnalysisTask: () -> Void,
        resetSelectionAndOutput: () -> Void,
        resetCompatibilityAndBatchState: () -> Void,
        resetFormatsAndSettings: () -> Void
    ) {
        cancelAnalysisTask()
        resetSelectionAndOutput()
        resetCompatibilityAndBatchState()
        resetFormatsAndSettings()
    }

    func clearSelectedSource(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)

        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(at: descriptor.analysisTask)
            },
            resetSelectionAndOutput: {
                self[keyPath: descriptor.sourceURL] = nil
                self[keyPath: descriptor.queuedSourceURLs] = []
                resetConversionOutputs(for: kind)
            },
            resetCompatibilityAndBatchState: {
                resetCompatibilityState(for: kind)
                self[keyPath: descriptor.isAnalyzing] = false
                self[keyPath: descriptor.currentBatchIndex] = 0
                self[keyPath: descriptor.totalBatchCount] = 0
            },
            resetFormatsAndSettings: {
                applyPlaceholderCapabilities(for: kind)
                applyDefaultSourceSettings(for: kind)
                scheduleCapabilityBootstrap(for: kind)
            }
        )
    }

    func resetConversionOutputs(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        self[keyPath: descriptor.convertedURL] = nil
        self[keyPath: descriptor.convertedURLs] = []
        self[keyPath: descriptor.conversionErrorMessage] = nil
    }

    func resetCompatibilityState(for kind: MediaKind, resetImageMetadata: Bool = true) {
        let descriptor = mediaStateDescriptor(for: kind)
        if kind == .image, resetImageMetadata {
            imageSourceFrameCount = 0
            imageSourceHasAlpha = false
        }
        self[keyPath: descriptor.compatibilityErrorMessage] = nil
        self[keyPath: descriptor.compatibilityWarningMessage] = nil
    }

    func resetSelectionCompatibilityState(for kind: MediaKind) {
        resetCompatibilityState(for: kind, resetImageMetadata: kind == .image)
    }
}
