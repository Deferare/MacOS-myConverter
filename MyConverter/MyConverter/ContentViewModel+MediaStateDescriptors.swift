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
    }

    static func resetImageCompatibilityMetadata(_ viewModel: ContentViewModel) {
        viewModel.updateState(\.imageRuntimeState, value: \.sourceFrameCount, to: 0)
        viewModel.updateState(\.imageRuntimeState, value: \.sourceHasAlpha, to: false)
    }

    private static let videoStateDescriptor = MediaStateDescriptor(
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
        pendingSelectionAnalysisTask: \.taskState.pendingVideoSelectionAnalysisTask
    )

    private static let imageStateDescriptor = MediaStateDescriptor(
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
        pendingSelectionAnalysisTask: \.taskState.pendingImageSelectionAnalysisTask
    )

    private static let audioStateDescriptor = MediaStateDescriptor(
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
        pendingSelectionAnalysisTask: \.taskState.pendingAudioSelectionAnalysisTask
    )

    func prepareConversionStartState(
        for kind: MediaKind,
        preserveCompletedOutputs: Bool = false
    ) {
        let descriptor = kind.mediaStateDescriptor
        self[keyPath: descriptor.isConverting] = true
        if !preserveCompletedOutputs {
            self[keyPath: descriptor.convertedURL] = nil
            self[keyPath: descriptor.convertedURLs] = []
            self[keyPath: descriptor.convertedOutputURLsBySourceID] = [:]
        }
        self[keyPath: descriptor.processedSourceIDs] = []
        self[keyPath: descriptor.conversionErrorMessage] = nil
        self[keyPath: descriptor.progress] = 0
    }

    func appendConvertedOutput(_ outputURL: URL, from sourceURL: URL, for kind: MediaKind) {
        let descriptor = kind.mediaStateDescriptor
        let sourceID = sourceIdentifier(for: sourceURL)
        self[keyPath: descriptor.convertedURL] = outputURL

        var convertedURLs = self[keyPath: descriptor.convertedURLs]
        convertedURLs.append(outputURL)
        self[keyPath: descriptor.convertedURLs] = convertedURLs

        var convertedOutputURLsBySourceID = self[keyPath: descriptor.convertedOutputURLsBySourceID]
        convertedOutputURLsBySourceID[sourceID] = outputURL
        self[keyPath: descriptor.convertedOutputURLsBySourceID] = convertedOutputURLsBySourceID
    }

    func markProcessedSource(_ sourceURL: URL, for kind: MediaKind) {
        let descriptor = kind.mediaStateDescriptor
        var processedSourceIDs = self[keyPath: descriptor.processedSourceIDs]
        processedSourceIDs.insert(sourceIdentifier(for: sourceURL))
        self[keyPath: descriptor.processedSourceIDs] = processedSourceIDs
    }

    func analyzeSelectedSources(_ urls: [URL], for kind: MediaKind) {
        kind.analyzeSelectionCompatibility(in: self, urls: urls)
    }

    func resetCompatibilityMetadata(for kind: MediaKind) {
        kind.resetCompatibilityMetadata(in: self)
    }

    func mediaStateSnapshot(for kind: MediaKind) -> MediaStateSnapshot {
        let descriptor = kind.mediaStateDescriptor

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

extension ContentViewModel.MediaKind {
    private struct MediaBehavior {
        let descriptor: ContentViewModel.MediaStateDescriptor
        let performConversion: @MainActor (ContentViewModel) async -> Void
        let analyzeSelectedSources: (ContentViewModel, [URL]) -> Void
        let resetCompatibilityMetadata: (ContentViewModel) -> Void
    }

    private static let mediaBehaviorByKind: [Self: MediaBehavior] = [
        .video: MediaBehavior(
            descriptor: ContentViewModel.videoStateDescriptor,
            performConversion: { viewModel in
                await viewModel.performVideoConversion()
            },
            analyzeSelectedSources: { viewModel, urls in
                Self.video.analyzeSelectionCompatibility(in: viewModel, urls: urls)
            },
            resetCompatibilityMetadata: { _ in }
        ),
        .image: MediaBehavior(
            descriptor: ContentViewModel.imageStateDescriptor,
            performConversion: { viewModel in
                await viewModel.performImageConversion()
            },
            analyzeSelectedSources: { viewModel, urls in
                Self.image.analyzeSelectionCompatibility(in: viewModel, urls: urls)
            },
            resetCompatibilityMetadata: { viewModel in
                ContentViewModel.resetImageCompatibilityMetadata(viewModel)
            }
        ),
        .audio: MediaBehavior(
            descriptor: ContentViewModel.audioStateDescriptor,
            performConversion: { viewModel in
                await viewModel.performAudioConversion()
            },
            analyzeSelectedSources: { viewModel, urls in
                Self.audio.analyzeSelectionCompatibility(in: viewModel, urls: urls)
            },
            resetCompatibilityMetadata: { _ in }
        )
    ]

    private var mediaBehavior: MediaBehavior {
        Self.mediaBehaviorByKind[self] ?? Self.mediaBehaviorByKind[.video]!
    }

    var mediaStateDescriptor: ContentViewModel.MediaStateDescriptor {
        mediaBehavior.descriptor
    }

    @MainActor
    func performConversion(in viewModel: ContentViewModel) async {
        await mediaBehavior.performConversion(viewModel)
    }

    func analyzeSelectedSources(_ urls: [URL], in viewModel: ContentViewModel) {
        mediaBehavior.analyzeSelectedSources(viewModel, urls)
    }

    func resetCompatibilityMetadata(in viewModel: ContentViewModel) {
        mediaBehavior.resetCompatibilityMetadata(viewModel)
    }
}
