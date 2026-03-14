import Foundation

extension ContentViewModel.MediaKind {
    func performConversion<OutputSettings: Sendable>(
        in viewModel: ContentViewModel,
        fileExtension: String,
        buildOutputSettings: () throws -> OutputSettings,
        prepareBatchEnvironment: @escaping @Sendable (
            [PreparedSourceConversion],
            OutputSettings
        ) async -> ContentViewModel.BatchExecutionEnvironment,
        prepareSingleSourceEnvironment: (
            @MainActor @Sendable (
                PreparedSourceConversion,
                OutputSettings
            ) async -> ContentViewModel.BatchExecutionEnvironment
        )? = nil,
        runConversion: @escaping (
            PreparedSourceConversion,
            ContentViewModel.BatchExecutionEnvironment,
            OutputSettings,
            Int,
            Int
        ) async throws -> URL
    ) async {
        let validationMessage = validationMessage(in: viewModel)
        let canConvert = canStartConversion(
            in: viewModel,
            validationMessage: validationMessage
        )

        await performMediaBatchConversion(
            in: viewModel,
            canConvert: canConvert,
            missingSourceLog: missingSourceLog,
            fileExtension: fileExtension,
            outputLabel: outputLabel,
            preferredOutputDestination: selectedOutputDestinationHandle(in: viewModel),
            preferredOutputDirectory: selectedOutputDirectoryURL(in: viewModel),
            skippedSummaryPrefix: skippedSummaryPrefix,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            startState: { outputDirectoryURL, preserveCompletedOutputs in
                self.setSelectedOutputDirectoryURL(outputDirectoryURL, in: viewModel)
                self.prepareConversionStartState(
                    in: viewModel,
                    preserveCompletedOutputs: preserveCompletedOutputs
                )
            },
            buildOutputSettings: buildOutputSettings,
            prepareBatchEnvironment: prepareBatchEnvironment,
            prepareSingleSourceEnvironment: prepareSingleSourceEnvironment,
            validate: { preparedSource, environment in
                await self.validatePreparedSourceOutputSettings(
                    in: viewModel,
                    source: preparedSource,
                    environment: environment
                )
            },
            runConversion: runConversion,
            onSavedOutput: { sourceURL, savedURL in
                self.appendConvertedOutput(savedURL, from: sourceURL, in: viewModel)
            },
            onSourceProcessed: { sourceURL in
                self.markProcessedSource(sourceURL, in: viewModel)
            },
            onError: { error in
                self.applyConversionError(
                    error,
                    in: viewModel,
                    logPrefix: self.errorLogPrefix,
                    treatExportCancellationAsCancelled: self.treatExportCancellationAsCancelled,
                    includeDebugInfo: self.includeDebugInfo
                )
            },
            onSingleSourceCompletion: {
                self.clearPreparedSingleVideoSelection(in: viewModel)
            }
        )
    }
}
