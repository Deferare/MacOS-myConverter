import Foundation

extension ContentViewModel {
    func resetCancelledConversionState(
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>
    ) {
        setProgress(0, at: progressKeyPath)
        self[keyPath: errorMessageKeyPath] = nil
    }

    func executeBatchConversion(
        preparedSources: [PreparedSourceConversion],
        batchEnvironment: BatchExecutionEnvironment,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        self[keyPath: totalBatchCountKeyPath] = preparedSources.count
        self[keyPath: currentBatchIndexKeyPath] = 0

        do {
            defer {
                self[keyPath: runningKeyPath] = false
                self[keyPath: currentBatchIndexKeyPath] = 0
                self[keyPath: totalBatchCountKeyPath] = 0
            }
            try Task.checkCancellation()

            let skippedEntries = try await runBatchConversionLoop(
                preparedSources: preparedSources,
                batchEnvironment: batchEnvironment,
                validate: validate,
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
            resetCancelledConversionState(
                progressKeyPath: progressKeyPath,
                errorMessageKeyPath: errorMessageKeyPath
            )
        } catch ConversionError.exportCancelled where treatExportCancellationAsCancelled {
            resetCancelledConversionState(
                progressKeyPath: progressKeyPath,
                errorMessageKeyPath: errorMessageKeyPath
            )
        } catch {
            onError(error)
        }
    }
}
