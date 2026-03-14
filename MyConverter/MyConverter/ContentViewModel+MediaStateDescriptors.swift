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

    func sourceURL(in viewModel: ContentViewModel) -> URL? {
        viewModel[keyPath: mediaStateDescriptor.sourceURL]
    }

    func setSourceURL(_ url: URL?, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.sourceURL] = url
    }

    func queuedSourceURLs(in viewModel: ContentViewModel) -> [URL] {
        viewModel[keyPath: mediaStateDescriptor.queuedSourceURLs]
    }

    func setQueuedSourceURLs(_ urls: [URL], in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.queuedSourceURLs] = urls
    }

    func convertedURL(in viewModel: ContentViewModel) -> URL? {
        viewModel[keyPath: mediaStateDescriptor.convertedURL]
    }

    func setConvertedURL(_ url: URL?, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.convertedURL] = url
    }

    func convertedURLs(in viewModel: ContentViewModel) -> [URL] {
        viewModel[keyPath: mediaStateDescriptor.convertedURLs]
    }

    func setConvertedURLs(_ urls: [URL], in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.convertedURLs] = urls
    }

    func convertedOutputURLsBySourceID(in viewModel: ContentViewModel) -> [String: URL] {
        viewModel[keyPath: mediaStateDescriptor.convertedOutputURLsBySourceID]
    }

    func setConvertedOutputURLsBySourceID(
        _ urlsBySourceID: [String: URL],
        in viewModel: ContentViewModel
    ) {
        viewModel[keyPath: mediaStateDescriptor.convertedOutputURLsBySourceID] = urlsBySourceID
    }

    func processedSourceIDs(in viewModel: ContentViewModel) -> Set<String> {
        viewModel[keyPath: mediaStateDescriptor.processedSourceIDs]
    }

    func setProcessedSourceIDs(_ sourceIDs: Set<String>, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.processedSourceIDs] = sourceIDs
    }

    func selectedSourceIDs(in viewModel: ContentViewModel) -> [String] {
        mediaStateSnapshot(in: viewModel).selectedSourceURLs.map(viewModel.sourceIdentifier(for:))
    }

    func hasSelectedSource(in viewModel: ContentViewModel) -> Bool {
        sourceURL(in: viewModel) != nil
    }

    func isAnalyzing(in viewModel: ContentViewModel) -> Bool {
        viewModel[keyPath: mediaStateDescriptor.isAnalyzing]
    }

    func isConverting(in viewModel: ContentViewModel) -> Bool {
        viewModel[keyPath: mediaStateDescriptor.isConverting]
    }

    func compatibilityErrorMessage(in viewModel: ContentViewModel) -> String? {
        viewModel[keyPath: mediaStateDescriptor.compatibilityErrorMessage]
    }

    func compatibilityWarningMessage(in viewModel: ContentViewModel) -> String? {
        viewModel[keyPath: mediaStateDescriptor.compatibilityWarningMessage]
    }

    func setAnalyzing(_ isAnalyzing: Bool, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.isAnalyzing] = isAnalyzing
    }

    func setAnalysisTask(_ task: Task<Void, Never>?, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.analysisTask] = task
    }

    func conversionTask(in viewModel: ContentViewModel) -> Task<Void, Never>? {
        viewModel[keyPath: mediaStateDescriptor.conversionTask]
    }

    func setConversionTask(_ task: Task<Void, Never>?, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.conversionTask] = task
    }

    func cancelAnalysisTask(in viewModel: ContentViewModel) {
        viewModel.cancelTask(at: mediaStateDescriptor.analysisTask)
    }

    func setConverting(_ isConverting: Bool, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.isConverting] = isConverting
    }

    func setCurrentBatchIndex(_ index: Int, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.currentBatchIndex] = index
    }

    func currentBatchIndex(in viewModel: ContentViewModel) -> Int {
        viewModel[keyPath: mediaStateDescriptor.currentBatchIndex]
    }

    func setTotalBatchCount(_ count: Int, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.totalBatchCount] = count
    }

    func totalBatchCount(in viewModel: ContentViewModel) -> Int {
        viewModel[keyPath: mediaStateDescriptor.totalBatchCount]
    }

    func conversionErrorMessage(in viewModel: ContentViewModel) -> String? {
        viewModel[keyPath: mediaStateDescriptor.conversionErrorMessage]
    }

    func setConversionErrorMessage(_ message: String?, in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.conversionErrorMessage] = message
    }

    func setCompatibilityMessages(
        warningMessage: String?,
        errorMessage: String?,
        in viewModel: ContentViewModel
    ) {
        viewModel[keyPath: mediaStateDescriptor.compatibilityWarningMessage] = warningMessage
        viewModel[keyPath: mediaStateDescriptor.compatibilityErrorMessage] = errorMessage
    }

    var pendingSelectionAnalysisTaskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?> {
        mediaStateDescriptor.pendingSelectionAnalysisTask
    }

    @MainActor
    func performConversion(in viewModel: ContentViewModel) async {
        await mediaBehavior.performConversion(viewModel)
    }

    func prepareConversionStartState(
        in viewModel: ContentViewModel,
        preserveCompletedOutputs: Bool = false
    ) {
        setConverting(true, in: viewModel)
        if !preserveCompletedOutputs {
            setConvertedURL(nil, in: viewModel)
            setConvertedURLs([], in: viewModel)
            setConvertedOutputURLsBySourceID([:], in: viewModel)
        }
        setProcessedSourceIDs([], in: viewModel)
        setConversionErrorMessage(nil, in: viewModel)
        setProgress(0, in: viewModel)
    }

    func appendConvertedOutput(
        _ outputURL: URL,
        from sourceURL: URL,
        in viewModel: ContentViewModel
    ) {
        let sourceID = viewModel.sourceIdentifier(for: sourceURL)
        setConvertedURL(outputURL, in: viewModel)

        var convertedURLs = convertedURLs(in: viewModel)
        convertedURLs.append(outputURL)
        setConvertedURLs(convertedURLs, in: viewModel)

        var convertedOutputURLsBySourceID = convertedOutputURLsBySourceID(in: viewModel)
        convertedOutputURLsBySourceID[sourceID] = outputURL
        setConvertedOutputURLsBySourceID(convertedOutputURLsBySourceID, in: viewModel)
    }

    func markProcessedSource(_ sourceURL: URL, in viewModel: ContentViewModel) {
        var processedSourceIDs = processedSourceIDs(in: viewModel)
        processedSourceIDs.insert(viewModel.sourceIdentifier(for: sourceURL))
        setProcessedSourceIDs(processedSourceIDs, in: viewModel)
    }

    func analyzeSelectedSources(_ urls: [URL], in viewModel: ContentViewModel) {
        mediaBehavior.analyzeSelectedSources(viewModel, urls)
    }

    func resetCompatibilityMetadata(in viewModel: ContentViewModel) {
        mediaBehavior.resetCompatibilityMetadata(viewModel)
    }

    func mediaStateSnapshot(in viewModel: ContentViewModel) -> ContentViewModel.MediaStateSnapshot {
        return ContentViewModel.MediaStateSnapshot(
            sourceURL: sourceURL(in: viewModel),
            queuedSourceURLs: queuedSourceURLs(in: viewModel),
            convertedURLs: convertedURLs(in: viewModel),
            convertedOutputURLsBySourceID: convertedOutputURLsBySourceID(in: viewModel),
            processedSourceIDs: processedSourceIDs(in: viewModel),
            conversionErrorMessage: conversionErrorMessage(in: viewModel),
            compatibilityWarningMessage: compatibilityWarningMessage(in: viewModel),
            isAnalyzing: isAnalyzing(in: viewModel),
            isConverting: isConverting(in: viewModel),
            progress: viewModel[keyPath: mediaStateDescriptor.progress],
            currentBatchIndex: currentBatchIndex(in: viewModel),
            totalBatchCount: totalBatchCount(in: viewModel)
        )
    }
}
