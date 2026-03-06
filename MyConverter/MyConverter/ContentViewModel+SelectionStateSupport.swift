import Foundation

extension ContentViewModel {
    enum MediaKind: Equatable {
        case video
        case image
        case audio
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
        let applyPlaceholderCapabilities: (ContentViewModel) -> Void
        let applyDefaultSettings: (ContentViewModel) -> Void
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
                analysisTask: \.sourceAnalysisTask,
                conversionTask: \.conversionTask,
                applyPlaceholderCapabilities: { $0.applyPlaceholderVideoCapabilities() },
                applyDefaultSettings: { $0.applyStoredSettings(.init()) }
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
                analysisTask: \.imageSourceAnalysisTask,
                conversionTask: \.imageConversionTask,
                applyPlaceholderCapabilities: { $0.applyPlaceholderImageCapabilities() },
                applyDefaultSettings: { $0.applyStoredImageSettings(.init()) }
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
                analysisTask: \.audioSourceAnalysisTask,
                conversionTask: \.audioConversionTask,
                applyPlaceholderCapabilities: { $0.applyPlaceholderAudioCapabilities() },
                applyDefaultSettings: { $0.applyStoredAudioSettings(.init()) }
            )
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
                descriptor.applyPlaceholderCapabilities(self)
                descriptor.applyDefaultSettings(self)
                scheduleCapabilityBootstrap()
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

    func resetVideoConversionOutputs() {
        resetConversionOutputs(for: .video)
    }

    func resetImageConversionOutputs() {
        resetConversionOutputs(for: .image)
    }

    func resetAudioConversionOutputs() {
        resetConversionOutputs(for: .audio)
    }

    func resetVideoCompatibilityMessages() {
        resetCompatibilityState(for: .video, resetImageMetadata: false)
    }

    func resetImageCompatibilityState(resetMetadata: Bool) {
        resetCompatibilityState(for: .image, resetImageMetadata: resetMetadata)
    }

    func resetAudioCompatibilityMessages() {
        resetCompatibilityState(for: .audio, resetImageMetadata: false)
    }
}
