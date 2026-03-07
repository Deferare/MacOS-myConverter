import Foundation

extension ContentViewModel {
    func executeBatchConversion(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        destinationErrorCode: Int,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        self[keyPath: totalBatchCountKeyPath] = sourceURLs.count
        self[keyPath: currentBatchIndexKeyPath] = 0

        do {
            defer {
                self[keyPath: runningKeyPath] = false
                self[keyPath: currentBatchIndexKeyPath] = 0
                self[keyPath: totalBatchCountKeyPath] = 0
            }
            try Task.checkCancellation()

            let skippedEntries = try await runBatchConversionLoop(
                sourceURLs: sourceURLs,
                destinationURLsBySourceID: destinationURLsBySourceID,
                destinationErrorCode: destinationErrorCode,
                validate: validate,
                makeWorkingOutputURL: makeWorkingOutputURL,
                runConversion: runConversion,
                onSavedOutput: onSavedOutput,
                onSourceProcessed: onSourceProcessed,
                onBatchIndexChanged: { index in
                    self[keyPath: currentBatchIndexKeyPath] = index
                }
            )

            setProgress(1, at: progressKeyPath)
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: skippedSummaryPrefix,
                entries: skippedEntries
            ) {
                self[keyPath: errorMessageKeyPath] = summary
            }
        } catch is CancellationError {
            setProgress(0, at: progressKeyPath)
            self[keyPath: errorMessageKeyPath] = nil
        } catch ConversionError.exportCancelled where treatExportCancellationAsCancelled {
            setProgress(0, at: progressKeyPath)
            self[keyPath: errorMessageKeyPath] = nil
        } catch {
            onError(error)
        }
    }
}
