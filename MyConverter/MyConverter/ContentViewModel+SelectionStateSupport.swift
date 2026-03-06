import Foundation

extension ContentViewModel {
    enum MediaKind: String, Equatable, Sendable, CaseIterable {
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
            switch self {
            case .video:
                return "film"
            case .image:
                return "photo"
            case .audio:
                return "waveform"
            }
        }

        var inputSystemImage: String {
            switch self {
            case .audio:
                return sidebarSystemImage
            case .video, .image:
                return "\(sidebarSystemImage).fill"
            }
        }
    }

    struct SelectedFileListState {
        let selectedURLs: [URL]
        let outputURLs: [URL]
        let isConverting: Bool
        let currentBatchIndex: Int
    }

    struct MediaStateSnapshot {
        let sourceURL: URL?
        let queuedSourceURLs: [URL]
        let convertedURLs: [URL]
        let conversionErrorMessage: String?
        let compatibilityWarningMessage: String?
        let isAnalyzing: Bool
        let isConverting: Bool
        let progress: Double
        let currentBatchIndex: Int
        let totalBatchCount: Int
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
        let sourceSettingsActions: SourceSettingsActions
        let capabilityBootstrap: CapabilityBootstrapDescriptor
        let validation: MediaValidationDescriptor
        let conversionExecution: ConversionExecutionDescriptor
        let resetCompatibilityMetadata: (ContentViewModel) -> Void
        let analyzeSelection: (ContentViewModel, [URL]) -> Void
    }

    func currentConversionTask(for kind: MediaKind) -> Task<Void, Never>? {
        let descriptor = mediaStateDescriptor(for: kind)
        return self[keyPath: descriptor.conversionTask]
    }

    func setConversionTask(_ task: Task<Void, Never>?, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        self[keyPath: descriptor.conversionTask] = task
    }

    func setConversionErrorMessage(_ message: String?, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        self[keyPath: descriptor.conversionErrorMessage] = message
    }

    func prepareConversionStartState(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        self[keyPath: descriptor.isConverting] = true
        self[keyPath: descriptor.convertedURL] = nil
        self[keyPath: descriptor.convertedURLs] = []
        self[keyPath: descriptor.conversionErrorMessage] = nil
        self[keyPath: descriptor.progress] = 0
    }

    func appendConvertedOutput(_ outputURL: URL, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        self[keyPath: descriptor.convertedURL] = outputURL
        var outputs = self[keyPath: descriptor.convertedURLs]
        outputs.append(outputURL)
        self[keyPath: descriptor.convertedURLs] = outputs
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
                conversionTask: \.taskState.conversionTask,
                sourceSettingsActions: makeSourceSettingsActions { $0.videoSettingsFlowDescriptor() },
                capabilityBootstrap: videoCapabilityBootstrapDescriptor(),
                validation: videoValidationDescriptor(),
                conversionExecution: makeConversionExecutionDescriptor {
                    $0.videoConversionWorkflowDescriptor()
                },
                resetCompatibilityMetadata: { _ in },
                analyzeSelection: { viewModel, urls in
                    viewModel.analyzeSourceCompatibility(
                        for: urls,
                        using: viewModel.videoSourceAnalysisDescriptor()
                    )
                }
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
                conversionTask: \.taskState.imageConversionTask,
                sourceSettingsActions: makeSourceSettingsActions { $0.imageSettingsFlowDescriptor() },
                capabilityBootstrap: imageCapabilityBootstrapDescriptor(),
                validation: imageValidationDescriptor(),
                conversionExecution: makeConversionExecutionDescriptor {
                    $0.imageConversionWorkflowDescriptor()
                },
                resetCompatibilityMetadata: { viewModel in
                    viewModel.imageSourceFrameCount = 0
                    viewModel.imageSourceHasAlpha = false
                },
                analyzeSelection: { viewModel, urls in
                    viewModel.analyzeSourceCompatibility(
                        for: urls,
                        using: viewModel.imageSourceAnalysisDescriptor()
                    )
                }
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
                conversionTask: \.taskState.audioConversionTask,
                sourceSettingsActions: makeSourceSettingsActions { $0.audioSettingsFlowDescriptor() },
                capabilityBootstrap: audioCapabilityBootstrapDescriptor(),
                validation: audioValidationDescriptor(),
                conversionExecution: makeConversionExecutionDescriptor {
                    $0.audioConversionWorkflowDescriptor()
                },
                resetCompatibilityMetadata: { _ in },
                analyzeSelection: { viewModel, urls in
                    viewModel.analyzeSourceCompatibility(
                        for: urls,
                        using: viewModel.audioSourceAnalysisDescriptor()
                    )
                }
            )
        }
    }

    func analyzeSelectedSources(_ urls: [URL], for kind: MediaKind) {
        mediaStateDescriptor(for: kind).analyzeSelection(self, urls)
    }

    func mediaStateSnapshot(for kind: MediaKind) -> MediaStateSnapshot {
        let descriptor = mediaStateDescriptor(for: kind)

        return MediaStateSnapshot(
            sourceURL: self[keyPath: descriptor.sourceURL],
            queuedSourceURLs: self[keyPath: descriptor.queuedSourceURLs],
            convertedURLs: self[keyPath: descriptor.convertedURLs],
            conversionErrorMessage: self[keyPath: descriptor.conversionErrorMessage],
            compatibilityWarningMessage: self[keyPath: descriptor.compatibilityWarningMessage],
            isAnalyzing: self[keyPath: descriptor.isAnalyzing],
            isConverting: self[keyPath: descriptor.isConverting],
            progress: self[keyPath: descriptor.progress],
            currentBatchIndex: self[keyPath: descriptor.currentBatchIndex],
            totalBatchCount: self[keyPath: descriptor.totalBatchCount]
        )
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
