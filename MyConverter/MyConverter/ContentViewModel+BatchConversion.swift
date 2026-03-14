import Foundation

extension ContentViewModel {
    struct ResolvedBatchOutputDirectory: Sendable {
        let outputDirectoryURL: URL
        let outputDirectoryAccessURL: URL
    }

    func performVideoConversion() async {
        await MediaKind.video.performConversion(
            in: self,
            fileExtension: selectedOutputFormatFileExtension(
                using: Self.videoOutputFormatDescriptor
            ),
            buildOutputSettings: { try self.buildVideoOutputSettings() },
            prepareBatchEnvironment: { preparedSources, outputSettings in
                await ContentViewModel.prepareVideoBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    outputSettings: outputSettings,
                    runtimeProvider: self.services.ffmpegRuntimeProvider
                )
            },
            prepareSingleSourceEnvironment: { preparedSource, outputSettings in
                await self.prepareSingleVideoBatchExecutionEnvironment(
                    preparedSource: preparedSource,
                    outputSettings: outputSettings
                )
            },
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await VideoConversionEngine.convert(
                    inputURL: preparedSource.sourceURL,
                    outputURL: preparedSource.workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil,
                    ffmpegContext: environment.videoFFmpegContext,
                    preparedSourceContext: environment.preparedVideoSources[preparedSource.sourceID],
                    onProgress: MediaKind.video.batchProgressHandler(
                        in: self,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func performImageConversion() async {
        await MediaKind.image.performConversion(
            in: self,
            fileExtension: selectedOutputFormatFileExtension(
                using: Self.imageOutputFormatDescriptor
            ),
            buildOutputSettings: { self.buildImageOutputSettings() },
            prepareBatchEnvironment: { preparedSources, _ in
                await ContentViewModel.prepareImageBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    runtimeProvider: self.services.ffmpegRuntimeProvider
                )
            },
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await ImageConversionEngine.convert(
                    inputURL: preparedSource.sourceURL,
                    outputURL: preparedSource.workingOutputURL,
                    outputSettings: outputSettings,
                    ffmpegContext: environment.imageFFmpegContext,
                    onProgress: MediaKind.image.batchProgressHandler(
                        in: self,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func performAudioConversion() async {
        await MediaKind.audio.performConversion(
            in: self,
            fileExtension: selectedOutputFormatFileExtension(
                using: Self.audioOutputFormatDescriptor
            ),
            buildOutputSettings: { self.buildAudioOutputSettings() },
            prepareBatchEnvironment: { preparedSources, _ in
                await ContentViewModel.prepareAudioBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    runtimeProvider: self.services.ffmpegRuntimeProvider
                )
            },
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await VideoConversionEngine.convertAudio(
                    inputURL: preparedSource.sourceURL,
                    outputURL: preparedSource.workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil,
                    ffmpegContext: environment.videoFFmpegContext,
                    runtimeProvider: self.services.ffmpegRuntimeProvider,
                    onProgress: MediaKind.audio.batchProgressHandler(
                        in: self,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }
}

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

    private func resolveBatchOutputDirectory(
        in viewModel: ContentViewModel,
        primarySourceURL: URL,
        preferredOutputDestination: OutputDestinationHandle?,
        preferredOutputDirectory: URL?,
        outputLabel: String,
        fileCount: Int
    ) async -> ContentViewModel.ResolvedBatchOutputDirectory? {
        if let preferredOutputDirectory {
            return ContentViewModel.ResolvedBatchOutputDirectory(
                outputDirectoryURL: preferredOutputDirectory.standardizedFileURL,
                outputDirectoryAccessURL: preferredOutputDestination?.url ?? preferredOutputDirectory
            )
        }

        guard let selectedDestination = await viewModel.services.outputDestinationCoordinator.chooseOutputDestination(
                suggestedDirectory: primarySourceURL.deletingLastPathComponent(),
                outputLabel: outputLabel,
                fileCount: fileCount
            ) else {
            return nil
        }

        return ContentViewModel.ResolvedBatchOutputDirectory(
            outputDirectoryURL: selectedDestination.url,
            outputDirectoryAccessURL: selectedDestination.url
        )
    }

    private func prepareBatchConversionContext(
        sourceURLs: [URL],
        fileExtension: String,
        outputDirectory: ContentViewModel.ResolvedBatchOutputDirectory
    ) async -> PreparedBatchConversionContext? {
        await detachedTaskValue(priority: .userInitiated) {
            BatchConversionSupport.prepareContext(
                sourceURLs: sourceURLs,
                fileExtension: fileExtension,
                outputDirectoryURL: outputDirectory.outputDirectoryURL,
                outputDirectoryAccessURL: outputDirectory.outputDirectoryAccessURL
            )
        }
    }

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
