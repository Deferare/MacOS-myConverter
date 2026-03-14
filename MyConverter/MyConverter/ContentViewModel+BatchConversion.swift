import Foundation

extension ContentViewModel {
    func performConversion<OutputSettings: Sendable>(
        for kind: MediaKind,
        fileExtension: String,
        buildOutputSettings: () throws -> OutputSettings,
        prepareBatchEnvironment: @escaping @Sendable ([PreparedSourceConversion], OutputSettings) async -> BatchExecutionEnvironment,
        prepareSingleSourceEnvironment: (
            @MainActor @Sendable (PreparedSourceConversion, OutputSettings) async -> BatchExecutionEnvironment
        )? = nil,
        runConversion: @escaping (
            PreparedSourceConversion,
            BatchExecutionEnvironment,
            OutputSettings,
            Int,
            Int
        ) async throws -> URL
    ) async {
        let validationMessage = kind.validationMessage(in: self)
        let canConvert = kind.canStartConversion(
            in: self,
            validationMessage: validationMessage
        )

        await performMediaBatchConversion(
            for: kind,
            canConvert: canConvert,
            missingSourceLog: kind.missingSourceLog,
            fileExtension: fileExtension,
            outputLabel: kind.outputLabel,
            preferredOutputDestination: kind.selectedOutputDestinationHandle(in: self),
            preferredOutputDirectory: kind.selectedOutputDirectoryURL(in: self),
            skippedSummaryPrefix: kind.skippedSummaryPrefix,
            treatExportCancellationAsCancelled: kind.treatExportCancellationAsCancelled,
            startState: { outputDirectoryURL, preserveCompletedOutputs in
                kind.setSelectedOutputDirectoryURL(outputDirectoryURL, in: self)
                kind.prepareConversionStartState(
                    in: self,
                    preserveCompletedOutputs: preserveCompletedOutputs
                )
            },
            buildOutputSettings: buildOutputSettings,
            prepareBatchEnvironment: prepareBatchEnvironment,
            prepareSingleSourceEnvironment: prepareSingleSourceEnvironment,
            validate: { preparedSource, environment in
                await kind.validatePreparedSourceOutputSettings(
                    in: self,
                    source: preparedSource,
                    environment: environment
                )
            },
            runConversion: runConversion,
            onSavedOutput: { sourceURL, savedURL in
                kind.appendConvertedOutput(savedURL, from: sourceURL, in: self)
            },
            onSourceProcessed: { sourceURL in
                kind.markProcessedSource(sourceURL, in: self)
            },
            onError: { error in
                kind.applyConversionError(
                    error,
                    in: self,
                    logPrefix: kind.errorLogPrefix,
                    treatExportCancellationAsCancelled: kind.treatExportCancellationAsCancelled,
                    includeDebugInfo: kind.includeDebugInfo
                )
            },
            onSingleSourceCompletion: {
                self.clearPreparedSingleVideoSelection(for: kind)
            }
        )
    }

    func performVideoConversion() async {
        await performConversion(
            for: .video,
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
                    onProgress: self.batchProgressHandler(
                        for: .video,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func performImageConversion() async {
        await performConversion(
            for: .image,
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
                    onProgress: self.batchProgressHandler(
                        for: .image,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func performAudioConversion() async {
        await performConversion(
            for: .audio,
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
                    onProgress: self.batchProgressHandler(
                        for: .audio,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func performMediaBatchConversion<OutputSettings: Sendable>(
        for kind: MediaKind,
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
        prepareBatchEnvironment: @escaping @Sendable ([PreparedSourceConversion], OutputSettings) async -> BatchExecutionEnvironment,
        prepareSingleSourceEnvironment: (@MainActor (PreparedSourceConversion, OutputSettings) async -> BatchExecutionEnvironment)? = nil,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, OutputSettings, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void,
        onSingleSourceCompletion: (() -> Void)? = nil
    ) async {
        let primarySourceURL = kind.sourceURL(in: self)
        guard canConvert, let primarySourceURL else {
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

        let allSourceURLs = [primarySourceURL] + kind.queuedSourceURLs(in: self)
        let existingOutputURLsBySourceID = kind.convertedOutputURLsBySourceID(in: self)
        let completedSourceIDs = Set(existingOutputURLsBySourceID.keys)
        let remainingSourceURLs = allSourceURLs.filter { sourceURL in
            !completedSourceIDs.contains(sourceIdentifier(for: sourceURL))
        }
        let shouldResumePartialBatch =
            !completedSourceIDs.isEmpty &&
            !remainingSourceURLs.isEmpty &&
            remainingSourceURLs.count < allSourceURLs.count
        let sourceURLs = shouldResumePartialBatch ? remainingSourceURLs : allSourceURLs

        let resolvedOutputDirectoryURL: URL
        let resolvedOutputDirectoryAccessURL: URL
        if let preferredOutputDirectory {
            resolvedOutputDirectoryURL = preferredOutputDirectory.standardizedFileURL
            resolvedOutputDirectoryAccessURL = preferredOutputDestination?.url ?? preferredOutputDirectory
        } else {
            guard let selectedDestination = await services.outputDestinationCoordinator.chooseOutputDestination(
                suggestedDirectory: primarySourceURL.deletingLastPathComponent(),
                outputLabel: outputLabel,
                fileCount: sourceURLs.count
            ) else {
                return
            }
            resolvedOutputDirectoryURL = selectedDestination.url
            resolvedOutputDirectoryAccessURL = selectedDestination.url
        }

        let batchContext = await detachedTaskValue(priority: .userInitiated) {
            BatchConversionSupport.prepareContext(
                sourceURLs: sourceURLs,
                fileExtension: fileExtension,
                outputDirectoryURL: resolvedOutputDirectoryURL,
                outputDirectoryAccessURL: resolvedOutputDirectoryAccessURL
            )
        }
        guard let batchContext else {
            return
        }

        defer { batchContext.stopAccessingBatchDirectory() }

        do {
            try Task.checkCancellation()
        } catch {
            return
        }

        startState(batchContext.outputDirectoryURL, shouldResumePartialBatch)
        if batchContext.preparedSources.count == 1,
           let preparedSource = batchContext.preparedSources.first,
           let prepareSingleSourceEnvironment {
            defer { onSingleSourceCompletion?() }
            await executeSingleSourceConversion(
                for: kind,
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
        await kind.executeBatchConversion(
            in: self,
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

    func executeSingleSourceConversion<OutputSettings: Sendable>(
        for kind: MediaKind,
        preparedSource: PreparedSourceConversion,
        outputSettings: OutputSettings,
        prepareSingleSourceEnvironment: @escaping @MainActor (
            PreparedSourceConversion,
            OutputSettings
        ) async -> BatchExecutionEnvironment,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, OutputSettings, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        kind.setTotalBatchCount(1, in: self)
        kind.setCurrentBatchIndex(1, in: self)

        await kind.performManagedConversionExecution(
            in: self,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            onError: onError
        ) {
            let batchEnvironment = await prepareSingleSourceEnvironment(
                preparedSource,
                outputSettings
            )

            let result = try await processPreparedSourceConversion(
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

            kind.setProgress(1, in: self)
            if let entry = result.skippedEntry {
                onSourceProcessed(preparedSource.sourceURL)
                kind.setConversionErrorMessage(BatchConversionSupport.skippedFilesSummary(
                    prefix: skippedSummaryPrefix,
                    entries: [entry]
                ), in: self)
            } else if let savedURL = result.savedURL {
                onSavedOutput(preparedSource.sourceURL, savedURL)
                onSourceProcessed(preparedSource.sourceURL)
            }
        }
    }
}
