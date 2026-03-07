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

    struct MediaDescriptorComponents {
        let state: MediaStateKeyPaths
        let tasks: MediaTaskKeyPaths
        let behavior: MediaBehaviorDescriptor
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

    func makeMediaBehaviorDescriptor<
        Settings: Equatable,
        Persisted: Codable,
        Format,
        Capability: Sendable,
        OutputSettings
    >(
        sourceSettings: @escaping (ContentViewModel) -> SourceSettingsFlowDescriptor<Settings, Persisted, Format>,
        capabilityBootstrap: CapabilityBootstrapDescriptor,
        validation: MediaValidationDescriptor,
        conversionWorkflow: @escaping (ContentViewModel) -> ConversionWorkflowDescriptor<OutputSettings>,
        resetCompatibilityMetadata: @escaping (ContentViewModel) -> Void = { _ in },
        sourceAnalysis: @escaping (ContentViewModel) -> SourceAnalysisDescriptor<Capability, Format>
    ) -> MediaBehaviorDescriptor {
        MediaBehaviorDescriptor(
            sourceSettingsActions: makeSourceSettingsActions(using: sourceSettings),
            capabilityBootstrap: capabilityBootstrap,
            validation: validation,
            conversionExecution: makeConversionExecutionDescriptor(workflow: conversionWorkflow),
            resetCompatibilityMetadata: resetCompatibilityMetadata,
            analyzeSelection: makeMediaSelectionAnalyzer(descriptor: sourceAnalysis)
        )
    }

    func videoMediaDescriptorComponents() -> MediaDescriptorComponents {
        MediaDescriptorComponents(
            state: MediaStateKeyPaths(
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
            ),
            tasks: MediaTaskKeyPaths(
                analysisTask: \.taskState.sourceAnalysisTask,
                conversionTask: \.taskState.conversionTask
            ),
            behavior: makeMediaBehaviorDescriptor(
                sourceSettings: { $0.videoSourceSettingsComponents().flow },
                capabilityBootstrap: videoCapabilityBootstrapDescriptor(),
                validation: videoValidationDescriptor(),
                conversionWorkflow: { $0.videoConversionWorkflowDescriptor() },
                sourceAnalysis: { $0.videoSourceAnalysisDescriptor() }
            )
        )
    }

    func imageMediaDescriptorComponents() -> MediaDescriptorComponents {
        MediaDescriptorComponents(
            state: MediaStateKeyPaths(
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
            ),
            tasks: MediaTaskKeyPaths(
                analysisTask: \.taskState.imageSourceAnalysisTask,
                conversionTask: \.taskState.imageConversionTask
            ),
            behavior: makeMediaBehaviorDescriptor(
                sourceSettings: { $0.imageSourceSettingsComponents().flow },
                capabilityBootstrap: imageCapabilityBootstrapDescriptor(),
                validation: imageValidationDescriptor(),
                conversionWorkflow: { $0.imageConversionWorkflowDescriptor() },
                resetCompatibilityMetadata: { viewModel in
                    viewModel.imageSourceFrameCount = 0
                    viewModel.imageSourceHasAlpha = false
                },
                sourceAnalysis: { $0.imageSourceAnalysisDescriptor() }
            )
        )
    }

    func audioMediaDescriptorComponents() -> MediaDescriptorComponents {
        MediaDescriptorComponents(
            state: MediaStateKeyPaths(
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
            ),
            tasks: MediaTaskKeyPaths(
                analysisTask: \.taskState.audioSourceAnalysisTask,
                conversionTask: \.taskState.audioConversionTask
            ),
            behavior: makeMediaBehaviorDescriptor(
                sourceSettings: { $0.audioSourceSettingsComponents().flow },
                capabilityBootstrap: audioCapabilityBootstrapDescriptor(),
                validation: audioValidationDescriptor(),
                conversionWorkflow: { $0.audioConversionWorkflowDescriptor() },
                sourceAnalysis: { $0.audioSourceAnalysisDescriptor() }
            )
        )
    }

    func mediaDescriptorComponents(for kind: MediaKind) -> MediaDescriptorComponents {
        switch kind {
        case .video:
            return videoMediaDescriptorComponents()
        case .image:
            return imageMediaDescriptorComponents()
        case .audio:
            return audioMediaDescriptorComponents()
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
        let components = mediaDescriptorComponents(for: kind)
        return makeMediaStateDescriptor(
            state: components.state,
            tasks: components.tasks,
            behavior: components.behavior
        )
    }

    func mediaBehaviorDescriptor(for kind: MediaKind) -> MediaBehaviorDescriptor {
        mediaDescriptorComponents(for: kind).behavior
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
