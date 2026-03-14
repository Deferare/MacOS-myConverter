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

    func performMediaBatchConversion<OutputSettings: Sendable>(
        in viewModel: ContentViewModel,
        canConvert: Bool,
        missingSourceLog: String,
        fileExtension: String,
        outputLabel: String,
        preferredOutputDestination: OutputDestinationHandle?,
        preferredOutputDirectory: URL?,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        startState: (URL, Bool) -> Void,
        buildOutputSettings: () throws -> OutputSettings,
        prepareBatchEnvironment: @escaping @Sendable (
            [PreparedSourceConversion],
            OutputSettings
        ) async -> ContentViewModel.BatchExecutionEnvironment,
        prepareSingleSourceEnvironment: (
            @MainActor (
                PreparedSourceConversion,
                OutputSettings
            ) async -> ContentViewModel.BatchExecutionEnvironment
        )? = nil,
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
        onError: (Error) -> Void,
        onSingleSourceCompletion: (() -> Void)? = nil
    ) async {
        let primarySourceURL = sourceURL(in: viewModel)
        guard
            canConvert,
            let sourceSelection = BatchSourceSelectionPlanner.resolve(
                primarySourceURL: primarySourceURL,
                queuedSourceURLs: queuedSourceURLs(in: viewModel),
                completedSourceIDs: Set(convertedOutputURLsBySourceID(in: viewModel).keys),
                sourceIdentifier: { viewModel.sourceIdentifier(for: $0) }
            ),
            let primarySourceURL
        else {
            if primarySourceURL == nil {
                print(missingSourceLog)
            }
            return
        }

        let outputSettings: OutputSettings
        do {
            outputSettings = try buildOutputSettings()
        } catch {
            onError(error)
            return
        }

        guard let resolvedOutputDirectory = await resolveBatchOutputDirectory(
            in: viewModel,
            primarySourceURL: primarySourceURL,
            preferredOutputDestination: preferredOutputDestination,
            preferredOutputDirectory: preferredOutputDirectory,
            outputLabel: outputLabel,
            fileCount: sourceSelection.sourceURLs.count
        ) else {
            return
        }

        let batchContext = await prepareBatchConversionContext(
            sourceURLs: sourceSelection.sourceURLs,
            fileExtension: fileExtension,
            outputDirectory: resolvedOutputDirectory
        )
        guard let batchContext else {
            return
        }

        defer { batchContext.stopAccessingBatchDirectory() }

        do {
            try Task.checkCancellation()
        } catch {
            return
        }

        startState(batchContext.outputDirectoryURL, sourceSelection.shouldResumePartialBatch)
        if batchContext.preparedSources.count == 1,
           let preparedSource = batchContext.preparedSources.first,
           let prepareSingleSourceEnvironment {
            defer { onSingleSourceCompletion?() }
            await executeSingleSourceConversion(
                in: viewModel,
                preparedSource: preparedSource,
                outputSettings: outputSettings,
                prepareSingleSourceEnvironment: prepareSingleSourceEnvironment,
                skippedSummaryPrefix: skippedSummaryPrefix,
                treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
                validate: validate,
                runConversion: runConversion,
                onSavedOutput: onSavedOutput,
                onSourceProcessed: onSourceProcessed,
                onError: onError
            )
            return
        }

        let batchEnvironment = await detachedTaskValue(priority: .userInitiated) {
            await prepareBatchEnvironment(
                batchContext.preparedSources,
                outputSettings
            )
        }
        await executeBatchConversion(
            in: viewModel,
            preparedSources: batchContext.preparedSources,
            batchEnvironment: batchEnvironment,
            skippedSummaryPrefix: skippedSummaryPrefix,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            validate: validate,
            runConversion: { preparedSource, environment, index, totalCount in
                try await runConversion(preparedSource, environment, outputSettings, index, totalCount)
            },
            onSavedOutput: onSavedOutput,
            onSourceProcessed: onSourceProcessed,
            onError: onError
        )
    }

}
