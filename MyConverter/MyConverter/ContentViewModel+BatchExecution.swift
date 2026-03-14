import Foundation

extension ContentViewModel {
    func resetCancelledConversionState(
        using descriptor: MediaStateDescriptor
    ) {
        setProgress(0, at: descriptor.progress)
        self[keyPath: descriptor.conversionErrorMessage] = nil
    }

    func performManagedConversionExecution(
        using descriptor: MediaStateDescriptor,
        treatExportCancellationAsCancelled: Bool = false,
        onError: (Error) -> Void,
        operation: () async throws -> Void
    ) async {
        do {
            defer {
                self[keyPath: descriptor.isConverting] = false
                self[keyPath: descriptor.currentBatchIndex] = 0
                self[keyPath: descriptor.totalBatchCount] = 0
            }
            try Task.checkCancellation()
            try await operation()
        } catch is CancellationError {
            resetCancelledConversionState(using: descriptor)
        } catch ConversionError.exportCancelled where treatExportCancellationAsCancelled {
            resetCancelledConversionState(using: descriptor)
        } catch {
            onError(error)
        }
    }

    func executeBatchConversion(
        preparedSources: [PreparedSourceConversion],
        batchEnvironment: BatchExecutionEnvironment,
        using descriptor: MediaStateDescriptor,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        self[keyPath: descriptor.totalBatchCount] = preparedSources.count
        self[keyPath: descriptor.currentBatchIndex] = 0

        await performManagedConversionExecution(
            using: descriptor,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            onError: onError
        ) {
            let skippedEntries = try await runBatchConversionLoop(
                preparedSources: preparedSources,
                batchEnvironment: batchEnvironment,
                validate: validate,
                runConversion: runConversion,
                onSavedOutput: onSavedOutput,
                onSourceProcessed: onSourceProcessed,
                onBatchIndexChanged: { index in
                    self[keyPath: descriptor.currentBatchIndex] = index
                }
            )

            setProgress(1, at: descriptor.progress)
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: skippedSummaryPrefix,
                entries: skippedEntries
            ) {
                self[keyPath: descriptor.conversionErrorMessage] = summary
            }
        }
    }
}
