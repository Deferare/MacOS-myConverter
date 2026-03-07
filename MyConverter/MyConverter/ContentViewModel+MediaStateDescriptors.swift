import Foundation

extension ContentViewModel {
    struct MediaStateSnapshot {
        let sourceURL: URL?
        let queuedSourceURLs: [URL]
        let convertedURLs: [URL]
        let convertedOutputURLsBySourceID: [String: URL]
        let processedSourceIDs: Set<String>
        let conversionErrorMessage: String?
        let compatibilityWarningMessage: String?
        let isAnalyzing: Bool
        let isConverting: Bool
        let progress: Double
        let currentBatchIndex: Int
        let totalBatchCount: Int
    }

    struct MediaStateKeyPaths {
        let sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let queuedSourceURLs: ReferenceWritableKeyPath<ContentViewModel, [URL]>
        let convertedURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let convertedURLs: ReferenceWritableKeyPath<ContentViewModel, [URL]>
        let convertedOutputURLsBySourceID: ReferenceWritableKeyPath<ContentViewModel, [String: URL]>
        let processedSourceIDs: ReferenceWritableKeyPath<ContentViewModel, Set<String>>
        let conversionErrorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let compatibilityErrorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let compatibilityWarningMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let isAnalyzing: ReferenceWritableKeyPath<ContentViewModel, Bool>
        let isConverting: ReferenceWritableKeyPath<ContentViewModel, Bool>
        let progress: ReferenceWritableKeyPath<ContentViewModel, Double>
        let currentBatchIndex: ReferenceWritableKeyPath<ContentViewModel, Int>
        let totalBatchCount: ReferenceWritableKeyPath<ContentViewModel, Int>
    }

    struct MediaTaskKeyPaths {
        let analysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let conversionTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
    }

    struct MediaBehaviorDescriptor {
        let sourceSettingsActions: SourceSettingsActions
        let capabilityBootstrap: CapabilityBootstrapDescriptor
        let validation: MediaValidationDescriptor
        let conversionExecution: ConversionExecutionDescriptor
        let resetCompatibilityMetadata: (ContentViewModel) -> Void
        let analyzeSelection: (ContentViewModel, [URL]) -> Void
    }

    struct MediaStateDescriptor {
        let sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let queuedSourceURLs: ReferenceWritableKeyPath<ContentViewModel, [URL]>
        let convertedURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let convertedURLs: ReferenceWritableKeyPath<ContentViewModel, [URL]>
        let convertedOutputURLsBySourceID: ReferenceWritableKeyPath<ContentViewModel, [String: URL]>
        let processedSourceIDs: ReferenceWritableKeyPath<ContentViewModel, Set<String>>
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

    func makeMediaStateDescriptor(
        state: MediaStateKeyPaths,
        tasks: MediaTaskKeyPaths,
        behavior: MediaBehaviorDescriptor
    ) -> MediaStateDescriptor {
        MediaStateDescriptor(
            sourceURL: state.sourceURL,
            queuedSourceURLs: state.queuedSourceURLs,
            convertedURL: state.convertedURL,
            convertedURLs: state.convertedURLs,
            convertedOutputURLsBySourceID: state.convertedOutputURLsBySourceID,
            processedSourceIDs: state.processedSourceIDs,
            conversionErrorMessage: state.conversionErrorMessage,
            compatibilityErrorMessage: state.compatibilityErrorMessage,
            compatibilityWarningMessage: state.compatibilityWarningMessage,
            isAnalyzing: state.isAnalyzing,
            isConverting: state.isConverting,
            progress: state.progress,
            currentBatchIndex: state.currentBatchIndex,
            totalBatchCount: state.totalBatchCount,
            analysisTask: tasks.analysisTask,
            conversionTask: tasks.conversionTask,
            sourceSettingsActions: behavior.sourceSettingsActions,
            capabilityBootstrap: behavior.capabilityBootstrap,
            validation: behavior.validation,
            conversionExecution: behavior.conversionExecution,
            resetCompatibilityMetadata: behavior.resetCompatibilityMetadata,
            analyzeSelection: behavior.analyzeSelection
        )
    }

    func makeMediaSelectionAnalyzer<Capability: Sendable, Format>(
        descriptor: @escaping (ContentViewModel) -> SourceAnalysisDescriptor<Capability, Format>
    ) -> (ContentViewModel, [URL]) -> Void {
        { viewModel, urls in
            viewModel.analyzeSourceCompatibility(
                for: urls,
                using: descriptor(viewModel)
            )
        }
    }

    func mediaStateKeyPaths(for kind: MediaKind) -> MediaStateKeyPaths {
        switch kind {
        case .video:
            return MediaStateKeyPaths(
                sourceURL: \.sourceURL,
                queuedSourceURLs: \.queuedSourceURLs,
                convertedURL: \.convertedURL,
                convertedURLs: \.convertedURLs,
                convertedOutputURLsBySourceID: \.convertedOutputURLsBySourceID,
                processedSourceIDs: \.processedSourceIDs,
                conversionErrorMessage: \.conversionErrorMessage,
                compatibilityErrorMessage: \.sourceCompatibilityErrorMessage,
                compatibilityWarningMessage: \.sourceCompatibilityWarningMessage,
                isAnalyzing: \.isAnalyzingSource,
                isConverting: \.isConverting,
                progress: \.conversionProgress,
                currentBatchIndex: \.currentVideoBatchIndex,
                totalBatchCount: \.totalVideoBatchCount
            )
        case .image:
            return MediaStateKeyPaths(
                sourceURL: \.imageSourceURL,
                queuedSourceURLs: \.queuedImageSourceURLs,
                convertedURL: \.convertedImageURL,
                convertedURLs: \.convertedImageURLs,
                convertedOutputURLsBySourceID: \.convertedImageOutputURLsBySourceID,
                processedSourceIDs: \.processedImageSourceIDs,
                conversionErrorMessage: \.imageConversionErrorMessage,
                compatibilityErrorMessage: \.imageSourceCompatibilityErrorMessage,
                compatibilityWarningMessage: \.imageSourceCompatibilityWarningMessage,
                isAnalyzing: \.isAnalyzingImageSource,
                isConverting: \.isImageConverting,
                progress: \.imageConversionProgress,
                currentBatchIndex: \.currentImageBatchIndex,
                totalBatchCount: \.totalImageBatchCount
            )
        case .audio:
            return MediaStateKeyPaths(
                sourceURL: \.audioSourceURL,
                queuedSourceURLs: \.queuedAudioSourceURLs,
                convertedURL: \.convertedAudioURL,
                convertedURLs: \.convertedAudioURLs,
                convertedOutputURLsBySourceID: \.convertedAudioOutputURLsBySourceID,
                processedSourceIDs: \.processedAudioSourceIDs,
                conversionErrorMessage: \.audioConversionErrorMessage,
                compatibilityErrorMessage: \.audioSourceCompatibilityErrorMessage,
                compatibilityWarningMessage: \.audioSourceCompatibilityWarningMessage,
                isAnalyzing: \.isAnalyzingAudioSource,
                isConverting: \.isAudioConverting,
                progress: \.audioConversionProgress,
                currentBatchIndex: \.currentAudioBatchIndex,
                totalBatchCount: \.totalAudioBatchCount
            )
        }
    }

    func mediaTaskKeyPaths(for kind: MediaKind) -> MediaTaskKeyPaths {
        switch kind {
        case .video:
            return MediaTaskKeyPaths(
                analysisTask: \.taskState.sourceAnalysisTask,
                conversionTask: \.taskState.conversionTask
            )
        case .image:
            return MediaTaskKeyPaths(
                analysisTask: \.taskState.imageSourceAnalysisTask,
                conversionTask: \.taskState.imageConversionTask
            )
        case .audio:
            return MediaTaskKeyPaths(
                analysisTask: \.taskState.audioSourceAnalysisTask,
                conversionTask: \.taskState.audioConversionTask
            )
        }
    }

    func mediaBehaviorDescriptor(for kind: MediaKind) -> MediaBehaviorDescriptor {
        switch kind {
        case .video:
            return MediaBehaviorDescriptor(
                sourceSettingsActions: makeSourceSettingsActions { $0.videoSettingsFlowDescriptor() },
                capabilityBootstrap: videoCapabilityBootstrapDescriptor(),
                validation: videoValidationDescriptor(),
                conversionExecution: makeConversionExecutionDescriptor {
                    $0.videoConversionWorkflowDescriptor()
                },
                resetCompatibilityMetadata: { _ in },
                analyzeSelection: makeMediaSelectionAnalyzer { $0.videoSourceAnalysisDescriptor() }
            )
        case .image:
            return MediaBehaviorDescriptor(
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
                analyzeSelection: makeMediaSelectionAnalyzer { $0.imageSourceAnalysisDescriptor() }
            )
        case .audio:
            return MediaBehaviorDescriptor(
                sourceSettingsActions: makeSourceSettingsActions { $0.audioSettingsFlowDescriptor() },
                capabilityBootstrap: audioCapabilityBootstrapDescriptor(),
                validation: audioValidationDescriptor(),
                conversionExecution: makeConversionExecutionDescriptor {
                    $0.audioConversionWorkflowDescriptor()
                },
                resetCompatibilityMetadata: { _ in },
                analyzeSelection: makeMediaSelectionAnalyzer { $0.audioSourceAnalysisDescriptor() }
            )
        }
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
        self[keyPath: descriptor.convertedOutputURLsBySourceID] = [:]
        self[keyPath: descriptor.processedSourceIDs] = []
        self[keyPath: descriptor.conversionErrorMessage] = nil
        self[keyPath: descriptor.progress] = 0
    }

    func appendConvertedOutput(_ outputURL: URL, from sourceURL: URL, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        let sourceID = sourceIdentifier(for: sourceURL)
        self[keyPath: descriptor.convertedURL] = outputURL
        var outputs = self[keyPath: descriptor.convertedURLs]
        outputs.append(outputURL)
        self[keyPath: descriptor.convertedURLs] = outputs
        var outputsBySourceID = self[keyPath: descriptor.convertedOutputURLsBySourceID]
        outputsBySourceID[sourceID] = outputURL
        self[keyPath: descriptor.convertedOutputURLsBySourceID] = outputsBySourceID
    }

    func markProcessedSource(_ sourceURL: URL, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        var processedSourceIDs = self[keyPath: descriptor.processedSourceIDs]
        processedSourceIDs.insert(sourceIdentifier(for: sourceURL))
        self[keyPath: descriptor.processedSourceIDs] = processedSourceIDs
    }

    func mediaStateDescriptor(for kind: MediaKind) -> MediaStateDescriptor {
        makeMediaStateDescriptor(
            state: mediaStateKeyPaths(for: kind),
            tasks: mediaTaskKeyPaths(for: kind),
            behavior: mediaBehaviorDescriptor(for: kind)
        )
    }

    func analyzeSelectedSources(_ urls: [URL], for kind: MediaKind) {
        mediaBehaviorDescriptor(for: kind).analyzeSelection(self, urls)
    }

    func mediaStateSnapshot(for kind: MediaKind) -> MediaStateSnapshot {
        let descriptor = mediaStateDescriptor(for: kind)

        return MediaStateSnapshot(
            sourceURL: self[keyPath: descriptor.sourceURL],
            queuedSourceURLs: self[keyPath: descriptor.queuedSourceURLs],
            convertedURLs: self[keyPath: descriptor.convertedURLs],
            convertedOutputURLsBySourceID: self[keyPath: descriptor.convertedOutputURLsBySourceID],
            processedSourceIDs: self[keyPath: descriptor.processedSourceIDs],
            conversionErrorMessage: self[keyPath: descriptor.conversionErrorMessage],
            compatibilityWarningMessage: self[keyPath: descriptor.compatibilityWarningMessage],
            isAnalyzing: self[keyPath: descriptor.isAnalyzing],
            isConverting: self[keyPath: descriptor.isConverting],
            progress: self[keyPath: descriptor.progress],
            currentBatchIndex: self[keyPath: descriptor.currentBatchIndex],
            totalBatchCount: self[keyPath: descriptor.totalBatchCount]
        )
    }
}
