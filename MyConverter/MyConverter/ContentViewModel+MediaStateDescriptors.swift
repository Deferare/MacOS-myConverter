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
        let pendingSelectionAnalysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
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
        let pendingSelectionAnalysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
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
            pendingSelectionAnalysisTask: tasks.pendingSelectionAnalysisTask,
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

    private func makeMediaDescriptorComponents<
        Settings: Equatable,
        Persisted: Codable,
        Format,
        Capability: Sendable,
        OutputSettings: Sendable
    >(
        state: MediaStateKeyPaths,
        tasks: MediaTaskKeyPaths,
        sourceSettings: @escaping (ContentViewModel) -> SourceSettingsFlowDescriptor<Settings, Persisted, Format>,
        capabilityBootstrap: CapabilityBootstrapDescriptor,
        validation: MediaValidationDescriptor,
        conversionWorkflow: @escaping (ContentViewModel) -> ConversionWorkflowDescriptor<OutputSettings>,
        resetCompatibilityMetadata: @escaping (ContentViewModel) -> Void = { _ in },
        sourceAnalysis: @escaping (ContentViewModel) -> SourceAnalysisDescriptor<Capability, Format>
    ) -> MediaDescriptorComponents {
        MediaDescriptorComponents(
            state: state,
            tasks: tasks,
            behavior: makeMediaBehaviorDescriptor(
                sourceSettings: sourceSettings,
                capabilityBootstrap: capabilityBootstrap,
                validation: validation,
                conversionWorkflow: conversionWorkflow,
                resetCompatibilityMetadata: resetCompatibilityMetadata,
                sourceAnalysis: sourceAnalysis
            )
        )
    }

    private func makeMediaStateKeyPaths(
        sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        queuedSourceURLs: ReferenceWritableKeyPath<ContentViewModel, [URL]>,
        convertedURL: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        convertedURLs: ReferenceWritableKeyPath<ContentViewModel, [URL]>,
        convertedOutputURLsBySourceID: ReferenceWritableKeyPath<ContentViewModel, [String: URL]>,
        processedSourceIDs: ReferenceWritableKeyPath<ContentViewModel, Set<String>>,
        conversionErrorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>,
        compatibilityErrorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>,
        compatibilityWarningMessage: ReferenceWritableKeyPath<ContentViewModel, String?>,
        isAnalyzing: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        isConverting: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progress: ReferenceWritableKeyPath<ContentViewModel, Double>,
        currentBatchIndex: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCount: ReferenceWritableKeyPath<ContentViewModel, Int>
    ) -> MediaStateKeyPaths {
        MediaStateKeyPaths(
            sourceURL: sourceURL,
            queuedSourceURLs: queuedSourceURLs,
            convertedURL: convertedURL,
            convertedURLs: convertedURLs,
            convertedOutputURLsBySourceID: convertedOutputURLsBySourceID,
            processedSourceIDs: processedSourceIDs,
            conversionErrorMessage: conversionErrorMessage,
            compatibilityErrorMessage: compatibilityErrorMessage,
            compatibilityWarningMessage: compatibilityWarningMessage,
            isAnalyzing: isAnalyzing,
            isConverting: isConverting,
            progress: progress,
            currentBatchIndex: currentBatchIndex,
            totalBatchCount: totalBatchCount
        )
    }

    private func makeMediaTaskKeyPaths(
        analysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        conversionTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        pendingSelectionAnalysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
    ) -> MediaTaskKeyPaths {
        MediaTaskKeyPaths(
            analysisTask: analysisTask,
            conversionTask: conversionTask,
            pendingSelectionAnalysisTask: pendingSelectionAnalysisTask
        )
    }

    func resetImageCompatibilityMetadata(_ viewModel: ContentViewModel) {
        viewModel.imageSourceFrameCount = 0
        viewModel.imageSourceHasAlpha = false
    }

    func resetCompatibilityMetadata(_: ContentViewModel) {
    }

    private func videoMediaDescriptorComponents() -> MediaDescriptorComponents {
        makeMediaDescriptorComponents(
            state: makeMediaStateKeyPaths(
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
            tasks: makeMediaTaskKeyPaths(
                analysisTask: \.taskState.sourceAnalysisTask,
                conversionTask: \.taskState.conversionTask,
                pendingSelectionAnalysisTask: \.taskState.pendingVideoSelectionAnalysisTask
            ),
            sourceSettings: { $0.videoSourceSettingsComponents().flow },
            capabilityBootstrap: videoCapabilityBootstrapDescriptor(),
            validation: videoValidationDescriptor(),
            conversionWorkflow: { $0.videoConversionWorkflowDescriptor() },
            resetCompatibilityMetadata: resetCompatibilityMetadata(_:),
            sourceAnalysis: { $0.videoSourceAnalysisDescriptor() }
        )
    }

    private func imageMediaDescriptorComponents() -> MediaDescriptorComponents {
        makeMediaDescriptorComponents(
            state: makeMediaStateKeyPaths(
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
            tasks: makeMediaTaskKeyPaths(
                analysisTask: \.taskState.imageSourceAnalysisTask,
                conversionTask: \.taskState.imageConversionTask,
                pendingSelectionAnalysisTask: \.taskState.pendingImageSelectionAnalysisTask
            ),
            sourceSettings: { $0.imageSourceSettingsComponents().flow },
            capabilityBootstrap: imageCapabilityBootstrapDescriptor(),
            validation: imageValidationDescriptor(),
            conversionWorkflow: { $0.imageConversionWorkflowDescriptor() },
            resetCompatibilityMetadata: resetImageCompatibilityMetadata(_:),
            sourceAnalysis: { $0.imageSourceAnalysisDescriptor() }
        )
    }

    private func audioMediaDescriptorComponents() -> MediaDescriptorComponents {
        makeMediaDescriptorComponents(
            state: makeMediaStateKeyPaths(
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
            tasks: makeMediaTaskKeyPaths(
                analysisTask: \.taskState.audioSourceAnalysisTask,
                conversionTask: \.taskState.audioConversionTask,
                pendingSelectionAnalysisTask: \.taskState.pendingAudioSelectionAnalysisTask
            ),
            sourceSettings: { $0.audioSourceSettingsComponents().flow },
            capabilityBootstrap: audioCapabilityBootstrapDescriptor(),
            validation: audioValidationDescriptor(),
            conversionWorkflow: { $0.audioConversionWorkflowDescriptor() },
            resetCompatibilityMetadata: resetCompatibilityMetadata(_:),
            sourceAnalysis: { $0.audioSourceAnalysisDescriptor() }
        )
    }

    func mediaStateValue<Value>(
        using descriptor: MediaStateDescriptor,
        _ keyPath: KeyPath<MediaStateDescriptor, ReferenceWritableKeyPath<ContentViewModel, Value>>
    ) -> Value {
        self[keyPath: descriptor[keyPath: keyPath]]
    }

    func setMediaStateValue<Value>(
        using descriptor: MediaStateDescriptor,
        _ keyPath: KeyPath<MediaStateDescriptor, ReferenceWritableKeyPath<ContentViewModel, Value>>,
        to newValue: Value
    ) {
        self[keyPath: descriptor[keyPath: keyPath]] = newValue
    }

    func updateMediaStateValue<Value>(
        using descriptor: MediaStateDescriptor,
        _ keyPath: KeyPath<MediaStateDescriptor, ReferenceWritableKeyPath<ContentViewModel, Value>>,
        _ update: (inout Value) -> Void
    ) {
        let stateKeyPath = descriptor[keyPath: keyPath]
        var value = self[keyPath: stateKeyPath]
        update(&value)
        self[keyPath: stateKeyPath] = value
    }

    func currentConversionTask(for kind: MediaKind) -> Task<Void, Never>? {
        let descriptor = mediaStateDescriptor(for: kind)
        return mediaStateValue(using: descriptor, \.conversionTask)
    }

    func setConversionTask(_ task: Task<Void, Never>?, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        setMediaStateValue(using: descriptor, \.conversionTask, to: task)
    }

    func setConversionErrorMessage(_ message: String?, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        setMediaStateValue(using: descriptor, \.conversionErrorMessage, to: message)
    }

    func prepareConversionStartState(
        for kind: MediaKind,
        preserveCompletedOutputs: Bool = false
    ) {
        let descriptor = mediaStateDescriptor(for: kind)
        setMediaStateValue(using: descriptor, \.isConverting, to: true)
        if !preserveCompletedOutputs {
            setMediaStateValue(using: descriptor, \.convertedURL, to: nil)
            setMediaStateValue(using: descriptor, \.convertedURLs, to: [])
            setMediaStateValue(using: descriptor, \.convertedOutputURLsBySourceID, to: [:])
        }
        setMediaStateValue(using: descriptor, \.processedSourceIDs, to: [])
        setMediaStateValue(using: descriptor, \.conversionErrorMessage, to: nil)
        setMediaStateValue(using: descriptor, \.progress, to: 0)
    }

    func appendConvertedOutput(_ outputURL: URL, from sourceURL: URL, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        let sourceID = sourceIdentifier(for: sourceURL)
        setMediaStateValue(using: descriptor, \.convertedURL, to: outputURL)
        updateMediaStateValue(using: descriptor, \.convertedURLs) {
            $0.append(outputURL)
        }
        updateMediaStateValue(using: descriptor, \.convertedOutputURLsBySourceID) {
            $0[sourceID] = outputURL
        }
    }

    func markProcessedSource(_ sourceURL: URL, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        updateMediaStateValue(using: descriptor, \.processedSourceIDs) {
            $0.insert(sourceIdentifier(for: sourceURL))
        }
    }

    func mediaStateDescriptor(for kind: MediaKind) -> MediaStateDescriptor {
        let components = kind.mediaDescriptorComponents(using: self)
        return makeMediaStateDescriptor(
            state: components.state,
            tasks: components.tasks,
            behavior: components.behavior
        )
    }

    func mediaBehaviorDescriptor(for kind: MediaKind) -> MediaBehaviorDescriptor {
        kind.mediaDescriptorComponents(using: self).behavior
    }

    func analyzeSelectedSources(_ urls: [URL], for kind: MediaKind) {
        mediaBehaviorDescriptor(for: kind).analyzeSelection(self, urls)
    }

    func mediaStateSnapshot(for kind: MediaKind) -> MediaStateSnapshot {
        let descriptor = mediaStateDescriptor(for: kind)

        return MediaStateSnapshot(
            sourceURL: mediaStateValue(using: descriptor, \.sourceURL),
            queuedSourceURLs: mediaStateValue(using: descriptor, \.queuedSourceURLs),
            convertedURLs: mediaStateValue(using: descriptor, \.convertedURLs),
            convertedOutputURLsBySourceID: mediaStateValue(using: descriptor, \.convertedOutputURLsBySourceID),
            processedSourceIDs: mediaStateValue(using: descriptor, \.processedSourceIDs),
            conversionErrorMessage: mediaStateValue(using: descriptor, \.conversionErrorMessage),
            compatibilityWarningMessage: mediaStateValue(using: descriptor, \.compatibilityWarningMessage),
            isAnalyzing: mediaStateValue(using: descriptor, \.isAnalyzing),
            isConverting: mediaStateValue(using: descriptor, \.isConverting),
            progress: mediaStateValue(using: descriptor, \.progress),
            currentBatchIndex: mediaStateValue(using: descriptor, \.currentBatchIndex),
            totalBatchCount: mediaStateValue(using: descriptor, \.totalBatchCount)
        )
    }
}

private extension ContentViewModel.MediaKind {
    func mediaDescriptorComponents(using viewModel: ContentViewModel) -> ContentViewModel.MediaDescriptorComponents {
        switch self {
        case .video:
            return viewModel.videoMediaDescriptorComponents()
        case .image:
            return viewModel.imageMediaDescriptorComponents()
        case .audio:
            return viewModel.audioMediaDescriptorComponents()
        }
    }
}
