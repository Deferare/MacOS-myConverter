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
}

extension ContentViewModel.MediaStateSnapshot {
    var selectedSourceURLs: [URL] {
        guard let sourceURL else { return [] }
        return [sourceURL] + queuedSourceURLs
    }

    var selectedFileCount: Int {
        sourceURL == nil ? 0 : queuedSourceURLs.count + 1
    }

    var displayedProgress: Double {
        let resolvedProgress = isConverting ? progress : 0
        return resolvedProgress < 0.01 ? 0 : resolvedProgress
    }

    var currentBatchItemProgress: Double {
        guard isConverting,
              currentBatchIndex > 0,
              totalBatchCount > 0 else {
            return 0
        }

        let completedBatchCount = Double(currentBatchIndex - 1)
        let totalBatchCount = Double(max(totalBatchCount, 1))
        let itemProgress = (progress * totalBatchCount) - completedBatchCount
        return ContentViewModelSupport.clampedProgress(itemProgress)
    }
}

extension ContentViewModel {
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
        let applyDefaultSourceSettings: (ContentViewModel) -> Void
        let applyStoredSourceSettings: (ContentViewModel, String) -> Void
        let persistCurrentSourceSettings: (ContentViewModel) -> Void
        let warmDefaultCapabilities: @Sendable () -> WarmedDefaultCapability
        let applyPlaceholderCapabilities: (ContentViewModel) -> Void
        let validationMessage: (ContentViewModel) -> String?
        let hintMessage: (ContentViewModel) -> String?
        let validateSourceOutputSettings: (ContentViewModel, URL) async -> String?
        let validatePreparedSourceOutputSettings: (
            ContentViewModel,
            PreparedSourceConversion,
            BatchExecutionEnvironment
        ) async -> String?
        let performConversion: @MainActor (ContentViewModel) async -> Void
        let resetCompatibilityMetadata: (ContentViewModel) -> Void
        let analyzeSelection: (ContentViewModel, [URL]) -> Void
    }

    static func resetImageCompatibilityMetadata(_ viewModel: ContentViewModel) {
        viewModel.updateState(\.imageRuntimeState, value: \.sourceFrameCount, to: 0)
        viewModel.updateState(\.imageRuntimeState, value: \.sourceHasAlpha, to: false)
    }

    static func resetCompatibilityMetadata(_: ContentViewModel) {
    }

    private static let videoStateDescriptorValue = MediaStateDescriptor(
        sourceURL: \.videoRuntimeState.media.sourceURL,
        queuedSourceURLs: \.videoRuntimeState.media.queuedSourceURLs,
        convertedURL: \.videoRuntimeState.media.convertedURL,
        convertedURLs: \.videoRuntimeState.media.convertedURLs,
        convertedOutputURLsBySourceID: \.videoRuntimeState.media.convertedOutputURLsBySourceID,
        processedSourceIDs: \.videoRuntimeState.media.processedSourceIDs,
        conversionErrorMessage: \.videoRuntimeState.media.conversionErrorMessage,
        compatibilityErrorMessage: \.videoRuntimeState.media.sourceCompatibilityErrorMessage,
        compatibilityWarningMessage: \.videoRuntimeState.media.sourceCompatibilityWarningMessage,
        isAnalyzing: \.videoRuntimeState.media.isAnalyzingSource,
        isConverting: \.videoRuntimeState.media.isConverting,
        progress: \.videoRuntimeState.media.conversionProgress,
        currentBatchIndex: \.videoRuntimeState.media.currentBatchIndex,
        totalBatchCount: \.videoRuntimeState.media.totalBatchCount,
        analysisTask: \.taskState.sourceAnalysisTask,
        conversionTask: \.taskState.conversionTask,
        pendingSelectionAnalysisTask: \.taskState.pendingVideoSelectionAnalysisTask,
        applyDefaultSourceSettings: { viewModel in
            let flow = videoSourceSettingsFlowValue
            viewModel.applySourceSettings(flow.defaultSettings(), using: flow)
        },
        applyStoredSourceSettings: { viewModel, sourceID in
            viewModel.applySourceSettingsForSource(
                sourceID: sourceID,
                using: videoSourceSettingsFlowValue
            )
        },
        persistCurrentSourceSettings: { viewModel in
            viewModel.persistCurrentSourceSettingsIfNeeded(using: videoSourceSettingsFlowValue)
        },
        warmDefaultCapabilities: {
            let warmedFormats = VideoConversionEngine.defaultOutputFormats()
            return WarmedDefaultCapability { viewModel in
                viewModel.applyWarmedOutputFormatsIfIdle(
                    warmedFormats,
                    for: .video,
                    formatDescriptor: videoOutputFormatDescriptorValue,
                    postApply: {
                        viewModel.refreshVideoCodecOptions()
                    }
                )
            }
        },
        applyPlaceholderCapabilities: { viewModel in
            videoOutputFormatDescriptorValue.applyAvailableFormats(
                ContentViewModelSupport.placeholderVideoFormats(),
                to: viewModel
            )
            viewModel.applyPlaceholderVideoCodecOptions()
        },
        validationMessage: videoValidationDescriptorValue.validationMessage,
        hintMessage: videoValidationDescriptorValue.hintMessage,
        validateSourceOutputSettings: videoValidationDescriptorValue.validateSourceOutputSettings,
        validatePreparedSourceOutputSettings: videoValidationDescriptorValue.validatePreparedSourceOutputSettings,
        performConversion: { viewModel in
            await viewModel.performConversion(using: videoConversionWorkflowProfile)
        },
        resetCompatibilityMetadata: resetCompatibilityMetadata(_:),
        analyzeSelection: { viewModel, urls in
            viewModel.analyzeSourceCompatibility(
                for: urls,
                using: videoSourceAnalysisDescriptorValue
            )
        }
    )

    private static let imageStateDescriptorValue = MediaStateDescriptor(
        sourceURL: \.imageRuntimeState.media.sourceURL,
        queuedSourceURLs: \.imageRuntimeState.media.queuedSourceURLs,
        convertedURL: \.imageRuntimeState.media.convertedURL,
        convertedURLs: \.imageRuntimeState.media.convertedURLs,
        convertedOutputURLsBySourceID: \.imageRuntimeState.media.convertedOutputURLsBySourceID,
        processedSourceIDs: \.imageRuntimeState.media.processedSourceIDs,
        conversionErrorMessage: \.imageRuntimeState.media.conversionErrorMessage,
        compatibilityErrorMessage: \.imageRuntimeState.media.sourceCompatibilityErrorMessage,
        compatibilityWarningMessage: \.imageRuntimeState.media.sourceCompatibilityWarningMessage,
        isAnalyzing: \.imageRuntimeState.media.isAnalyzingSource,
        isConverting: \.imageRuntimeState.media.isConverting,
        progress: \.imageRuntimeState.media.conversionProgress,
        currentBatchIndex: \.imageRuntimeState.media.currentBatchIndex,
        totalBatchCount: \.imageRuntimeState.media.totalBatchCount,
        analysisTask: \.taskState.imageSourceAnalysisTask,
        conversionTask: \.taskState.imageConversionTask,
        pendingSelectionAnalysisTask: \.taskState.pendingImageSelectionAnalysisTask,
        applyDefaultSourceSettings: { viewModel in
            let flow = imageSourceSettingsFlowValue
            viewModel.applySourceSettings(flow.defaultSettings(), using: flow)
        },
        applyStoredSourceSettings: { viewModel, sourceID in
            viewModel.applySourceSettingsForSource(
                sourceID: sourceID,
                using: imageSourceSettingsFlowValue
            )
        },
        persistCurrentSourceSettings: { viewModel in
            viewModel.persistCurrentSourceSettingsIfNeeded(using: imageSourceSettingsFlowValue)
        },
        warmDefaultCapabilities: {
            let warmedFormats = ImageConversionEngine.defaultOutputFormats()
            return WarmedDefaultCapability { viewModel in
                viewModel.applyWarmedOutputFormatsIfIdle(
                    warmedFormats,
                    for: .image,
                    formatDescriptor: imageOutputFormatDescriptorValue
                )
            }
        },
        applyPlaceholderCapabilities: { viewModel in
            imageOutputFormatDescriptorValue.applyAvailableFormats(
                ContentViewModelSupport.placeholderImageFormats(),
                to: viewModel
            )
        },
        validationMessage: imageValidationDescriptorValue.validationMessage,
        hintMessage: imageValidationDescriptorValue.hintMessage,
        validateSourceOutputSettings: imageValidationDescriptorValue.validateSourceOutputSettings,
        validatePreparedSourceOutputSettings: imageValidationDescriptorValue.validatePreparedSourceOutputSettings,
        performConversion: { viewModel in
            await viewModel.performConversion(using: imageConversionWorkflowProfile)
        },
        resetCompatibilityMetadata: resetImageCompatibilityMetadata(_:),
        analyzeSelection: { viewModel, urls in
            viewModel.analyzeSourceCompatibility(
                for: urls,
                using: imageSourceAnalysisDescriptorValue
            )
        }
    )

    private static let audioStateDescriptorValue = MediaStateDescriptor(
        sourceURL: \.audioRuntimeState.media.sourceURL,
        queuedSourceURLs: \.audioRuntimeState.media.queuedSourceURLs,
        convertedURL: \.audioRuntimeState.media.convertedURL,
        convertedURLs: \.audioRuntimeState.media.convertedURLs,
        convertedOutputURLsBySourceID: \.audioRuntimeState.media.convertedOutputURLsBySourceID,
        processedSourceIDs: \.audioRuntimeState.media.processedSourceIDs,
        conversionErrorMessage: \.audioRuntimeState.media.conversionErrorMessage,
        compatibilityErrorMessage: \.audioRuntimeState.media.sourceCompatibilityErrorMessage,
        compatibilityWarningMessage: \.audioRuntimeState.media.sourceCompatibilityWarningMessage,
        isAnalyzing: \.audioRuntimeState.media.isAnalyzingSource,
        isConverting: \.audioRuntimeState.media.isConverting,
        progress: \.audioRuntimeState.media.conversionProgress,
        currentBatchIndex: \.audioRuntimeState.media.currentBatchIndex,
        totalBatchCount: \.audioRuntimeState.media.totalBatchCount,
        analysisTask: \.taskState.audioSourceAnalysisTask,
        conversionTask: \.taskState.audioConversionTask,
        pendingSelectionAnalysisTask: \.taskState.pendingAudioSelectionAnalysisTask,
        applyDefaultSourceSettings: { viewModel in
            let flow = audioSourceSettingsFlowValue
            viewModel.applySourceSettings(flow.defaultSettings(), using: flow)
        },
        applyStoredSourceSettings: { viewModel, sourceID in
            viewModel.applySourceSettingsForSource(
                sourceID: sourceID,
                using: audioSourceSettingsFlowValue
            )
        },
        persistCurrentSourceSettings: { viewModel in
            viewModel.persistCurrentSourceSettingsIfNeeded(using: audioSourceSettingsFlowValue)
        },
        warmDefaultCapabilities: {
            let warmedFormats = VideoConversionEngine.defaultAudioOutputFormats()
            return WarmedDefaultCapability { viewModel in
                viewModel.applyWarmedOutputFormatsIfIdle(
                    warmedFormats,
                    for: .audio,
                    formatDescriptor: audioOutputFormatDescriptorValue,
                    postApply: {
                        viewModel.refreshAudioCodecOptions()
                    }
                )
            }
        },
        applyPlaceholderCapabilities: { viewModel in
            audioOutputFormatDescriptorValue.applyAvailableFormats(
                ContentViewModelSupport.placeholderAudioFormats(),
                to: viewModel
            )
            viewModel.applyPlaceholderAudioCodecOptions()
        },
        validationMessage: audioValidationDescriptorValue.validationMessage,
        hintMessage: audioValidationDescriptorValue.hintMessage,
        validateSourceOutputSettings: audioValidationDescriptorValue.validateSourceOutputSettings,
        validatePreparedSourceOutputSettings: audioValidationDescriptorValue.validatePreparedSourceOutputSettings,
        performConversion: { viewModel in
            await viewModel.performConversion(using: audioConversionWorkflowProfile)
        },
        resetCompatibilityMetadata: resetCompatibilityMetadata(_:),
        analyzeSelection: { viewModel, urls in
            viewModel.analyzeSourceCompatibility(
                for: urls,
                using: audioSourceAnalysisDescriptorValue
            )
        }
    )

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

    static func mediaStateDescriptor(for kind: MediaKind) -> MediaStateDescriptor {
        kind.mediaStateDescriptor
    }

    func mediaStateDescriptor(for kind: MediaKind) -> MediaStateDescriptor {
        Self.mediaStateDescriptor(for: kind)
    }

    func analyzeSelectedSources(_ urls: [URL], for kind: MediaKind) {
        mediaStateDescriptor(for: kind).analyzeSelection(self, urls)
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
    private static let mediaStateDescriptorsByKind: [Self: ContentViewModel.MediaStateDescriptor] = [
        .video: ContentViewModel.videoStateDescriptorValue,
        .image: ContentViewModel.imageStateDescriptorValue,
        .audio: ContentViewModel.audioStateDescriptorValue
    ]

    var mediaStateDescriptor: ContentViewModel.MediaStateDescriptor {
        Self.mediaStateDescriptorsByKind[self] ?? ContentViewModel.videoStateDescriptorValue
    }
}
