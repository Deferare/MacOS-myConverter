import Foundation

extension ContentViewModel.MediaKind {
    func executeSingleSourceConversion<OutputSettings: Sendable>(
        in viewModel: ContentViewModel,
        preparedSource: PreparedSourceConversion,
        outputSettings: OutputSettings,
        prepareSingleSourceEnvironment: @escaping @MainActor (
            PreparedSourceConversion,
            OutputSettings
        ) async -> ContentViewModel.BatchExecutionEnvironment,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (
            PreparedSourceConversion,
            ContentViewModel.BatchExecutionEnvironment
        ) async -> String?,
        runConversion: @escaping (
            PreparedSourceConversion,
            ContentViewModel.BatchExecutionEnvironment,
            OutputSettings,
            Int,
            Int
        ) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        setTotalBatchCount(1, in: viewModel)
        setCurrentBatchIndex(1, in: viewModel)

        await performManagedConversionExecution(
            in: viewModel,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            onError: onError
        ) {
            let batchEnvironment = await prepareSingleSourceEnvironment(
                preparedSource,
                outputSettings
            )

            let result = try await viewModel.processPreparedSourceConversion(
                preparedSource,
                batchEnvironment: batchEnvironment,
                validate: validate,
                runConversion: {
                    try await runConversion(
                        preparedSource,
                        batchEnvironment,
                        outputSettings,
                        0,
                        1
                    )
                }
            )

            self.setProgress(1, in: viewModel)
            switch result {
            case let .skipped(entry):
                onSourceProcessed(preparedSource.sourceURL)
                self.setConversionErrorMessage(BatchConversionSupport.skippedFilesSummary(
                    prefix: skippedSummaryPrefix,
                    entries: [entry]
                ), in: viewModel)
            case let .saved(savedURL):
                onSavedOutput(preparedSource.sourceURL, savedURL)
                onSourceProcessed(preparedSource.sourceURL)
            }
        }
    }
}
