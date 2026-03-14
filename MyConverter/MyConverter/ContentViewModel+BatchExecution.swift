import Foundation

extension ContentViewModel {
    func resetCancelledConversionState(
        for kind: MediaKind
    ) {
        kind.setProgress(0, in: self)
        kind.setConversionErrorMessage(nil, in: self)
    }

    func performManagedConversionExecution(
        for kind: MediaKind,
        treatExportCancellationAsCancelled: Bool = false,
        onError: (Error) -> Void,
        operation: () async throws -> Void
    ) async {
        do {
            defer {
                kind.setConverting(false, in: self)
                kind.setCurrentBatchIndex(0, in: self)
                kind.setTotalBatchCount(0, in: self)
            }
            try Task.checkCancellation()
            try await operation()
        } catch is CancellationError {
            resetCancelledConversionState(for: kind)
        } catch ConversionError.exportCancelled where treatExportCancellationAsCancelled {
            resetCancelledConversionState(for: kind)
        } catch {
            onError(error)
        }
    }

    func executeBatchConversion(
        for kind: MediaKind,
        preparedSources: [PreparedSourceConversion],
        batchEnvironment: BatchExecutionEnvironment,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        kind.setTotalBatchCount(preparedSources.count, in: self)
        kind.setCurrentBatchIndex(0, in: self)

        await performManagedConversionExecution(
            for: kind,
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
                    kind.setCurrentBatchIndex(index, in: self)
                }
            )

            kind.setProgress(1, in: self)
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: skippedSummaryPrefix,
                entries: skippedEntries
            ) {
                kind.setConversionErrorMessage(summary, in: self)
            }
        }
    }
}
