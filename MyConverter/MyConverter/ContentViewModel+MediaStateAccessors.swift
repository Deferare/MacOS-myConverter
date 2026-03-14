import Foundation

extension ContentViewModel.MediaKind {
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
}
