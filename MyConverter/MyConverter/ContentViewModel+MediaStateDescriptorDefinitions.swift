import Foundation

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

    static let videoStateDescriptor = MediaStateDescriptor(
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

    static let imageStateDescriptor = MediaStateDescriptor(
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

    static let audioStateDescriptor = MediaStateDescriptor(
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
