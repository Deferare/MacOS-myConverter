import Foundation

extension ContentViewModel.MediaKind {
    func resetCancelledConversionState(in viewModel: ContentViewModel) {
        setProgress(0, in: viewModel)
        setConversionErrorMessage(nil, in: viewModel)
    }

    func performManagedConversionExecution(
        in viewModel: ContentViewModel,
        treatExportCancellationAsCancelled: Bool = false,
        onError: (Error) -> Void,
        operation: () async throws -> Void
    ) async {
        do {
            defer {
                setConverting(false, in: viewModel)
                setCurrentBatchIndex(0, in: viewModel)
                setTotalBatchCount(0, in: viewModel)
            }
            try Task.checkCancellation()
            try await operation()
        } catch is CancellationError {
            resetCancelledConversionState(in: viewModel)
        } catch ConversionError.exportCancelled where treatExportCancellationAsCancelled {
            resetCancelledConversionState(in: viewModel)
        } catch {
            onError(error)
        }
    }

    func executeBatchConversion(
        in viewModel: ContentViewModel,
        preparedSources: [PreparedSourceConversion],
        batchEnvironment: ContentViewModel.BatchExecutionEnvironment,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (PreparedSourceConversion, ContentViewModel.BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (
            PreparedSourceConversion,
            ContentViewModel.BatchExecutionEnvironment,
            Int,
            Int
        ) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        setTotalBatchCount(preparedSources.count, in: viewModel)
        setCurrentBatchIndex(0, in: viewModel)

        await performManagedConversionExecution(
            in: viewModel,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            onError: onError
        ) {
            let skippedEntries = try await viewModel.runBatchConversionLoop(
                preparedSources: preparedSources,
                batchEnvironment: batchEnvironment,
                validate: validate,
                runConversion: runConversion,
                onSavedOutput: onSavedOutput,
                onSourceProcessed: onSourceProcessed,
                onBatchIndexChanged: { index in
                    self.setCurrentBatchIndex(index, in: viewModel)
                }
            )

            self.setProgress(1, in: viewModel)
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: skippedSummaryPrefix,
                entries: skippedEntries
            ) {
                self.setConversionErrorMessage(summary, in: viewModel)
            }
        }
    }
}
