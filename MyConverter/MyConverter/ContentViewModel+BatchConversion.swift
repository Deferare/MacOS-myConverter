import Foundation

extension ContentViewModel {
    struct ConversionWorkflowProfile<OutputSettings: Sendable> {
        let kind: MediaKind
        let fileExtension: (ContentViewModel) -> String
        let buildOutputSettings: (ContentViewModel) throws -> OutputSettings
        let prepareBatchEnvironment: @Sendable (
            ContentViewModel,
            [PreparedSourceConversion],
            OutputSettings
        ) async -> BatchExecutionEnvironment
        let prepareSingleSourceEnvironment: (
            @MainActor @Sendable (
                ContentViewModel,
                PreparedSourceConversion,
                OutputSettings
            ) async -> BatchExecutionEnvironment
        )?
        let runConversion: (
            ContentViewModel,
            PreparedSourceConversion,
            BatchExecutionEnvironment,
            OutputSettings,
            Int,
            Int
        ) async throws -> URL
    }

    struct ConversionWorkflowDescriptor<OutputSettings: Sendable> {
        let kind: MediaKind
        let canConvert: Bool
        let fileExtension: String
        let metadata: ConversionMetadata
        let buildOutputSettings: () throws -> OutputSettings
        let prepareBatchEnvironment: @Sendable ([PreparedSourceConversion], OutputSettings) async -> BatchExecutionEnvironment
        let prepareSingleSourceEnvironment: (
            @MainActor @Sendable (
                PreparedSourceConversion,
                OutputSettings
            ) async -> BatchExecutionEnvironment
        )?
        let validate: (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?
        let runConversion: (PreparedSourceConversion, BatchExecutionEnvironment, OutputSettings, Int, Int) async throws -> URL
    }

    struct ConversionExecutionDescriptor {
        let execute: @MainActor (ContentViewModel) async -> Void
    }

    static func makeConversionExecutionDescriptor<OutputSettings: Sendable>(
        workflow: @escaping (ContentViewModel) -> ConversionWorkflowDescriptor<OutputSettings>
    ) -> ConversionExecutionDescriptor {
        ConversionExecutionDescriptor { viewModel in
            await viewModel.performConversion(using: workflow(viewModel))
        }
    }

    static let videoConversionWorkflowProfile = ConversionWorkflowProfile<VideoOutputSettings>(
        kind: .video,
        fileExtension: { viewModel in
            viewModel.selectedOutputFormatFileExtension(using: viewModel.videoOutputFormatDescriptor())
        },
        buildOutputSettings: { try $0.buildVideoOutputSettings() },
        prepareBatchEnvironment: { viewModel, preparedSources, outputSettings in
            await ContentViewModel.prepareVideoBatchExecutionEnvironment(
                preparedSources: preparedSources,
                outputSettings: outputSettings,
                runtimeProvider: viewModel.services.ffmpegRuntimeProvider
            )
        },
        prepareSingleSourceEnvironment: { viewModel, preparedSource, outputSettings in
            await viewModel.prepareSingleVideoBatchExecutionEnvironment(
                preparedSource: preparedSource,
                outputSettings: outputSettings
            )
        },
        runConversion: { viewModel, preparedSource, environment, outputSettings, index, totalCount in
            try await VideoConversionEngine.convert(
                inputURL: preparedSource.sourceURL,
                outputURL: preparedSource.workingOutputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: nil,
                ffmpegContext: environment.videoFFmpegContext,
                preparedSourceContext: environment.preparedVideoSources[preparedSource.sourceID],
                onProgress: viewModel.batchProgressHandler(
                    for: .video,
                    index: index,
                    totalCount: totalCount
                )
            )
        }
    )

    static let imageConversionWorkflowProfile = ConversionWorkflowProfile<ImageOutputSettings>(
        kind: .image,
        fileExtension: { viewModel in
            viewModel.selectedOutputFormatFileExtension(using: viewModel.imageOutputFormatDescriptor())
        },
        buildOutputSettings: { $0.buildImageOutputSettings() },
        prepareBatchEnvironment: { viewModel, preparedSources, _ in
            await ContentViewModel.prepareImageBatchExecutionEnvironment(
                preparedSources: preparedSources,
                runtimeProvider: viewModel.services.ffmpegRuntimeProvider
            )
        },
        prepareSingleSourceEnvironment: nil,
        runConversion: { viewModel, preparedSource, environment, outputSettings, index, totalCount in
            try await ImageConversionEngine.convert(
                inputURL: preparedSource.sourceURL,
                outputURL: preparedSource.workingOutputURL,
                outputSettings: outputSettings,
                ffmpegContext: environment.imageFFmpegContext,
                onProgress: viewModel.batchProgressHandler(
                    for: .image,
                    index: index,
                    totalCount: totalCount
                )
            )
        }
    )

    static let audioConversionWorkflowProfile = ConversionWorkflowProfile<AudioOutputSettings>(
        kind: .audio,
        fileExtension: { viewModel in
            viewModel.selectedOutputFormatFileExtension(using: viewModel.audioOutputFormatDescriptor())
        },
        buildOutputSettings: { $0.buildAudioOutputSettings() },
        prepareBatchEnvironment: { viewModel, preparedSources, _ in
            await ContentViewModel.prepareAudioBatchExecutionEnvironment(
                preparedSources: preparedSources,
                runtimeProvider: viewModel.services.ffmpegRuntimeProvider
            )
        },
        prepareSingleSourceEnvironment: nil,
        runConversion: { viewModel, preparedSource, environment, outputSettings, index, totalCount in
            try await VideoConversionEngine.convertAudio(
                inputURL: preparedSource.sourceURL,
                outputURL: preparedSource.workingOutputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: nil,
                ffmpegContext: environment.videoFFmpegContext,
                runtimeProvider: viewModel.services.ffmpegRuntimeProvider,
                onProgress: viewModel.batchProgressHandler(
                    for: .audio,
                    index: index,
                    totalCount: totalCount
                )
            )
        }
    )

    func makeConversionWorkflowDescriptor<OutputSettings: Sendable>(
        kind: MediaKind,
        fileExtension: String,
        metadata: ConversionMetadata,
        buildOutputSettings: @escaping () throws -> OutputSettings,
        prepareBatchEnvironment: @escaping @Sendable ([PreparedSourceConversion], OutputSettings) async -> BatchExecutionEnvironment,
        prepareSingleSourceEnvironment: (@MainActor (PreparedSourceConversion, OutputSettings) async -> BatchExecutionEnvironment)? = nil,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, OutputSettings, Int, Int) async throws -> URL
    ) -> ConversionWorkflowDescriptor<OutputSettings> {
        ConversionWorkflowDescriptor(
            kind: kind,
            canConvert: canStartConversion(
                for: kind,
                validationMessage: validationMessage(for: kind)
            ),
            fileExtension: fileExtension,
            metadata: metadata,
            buildOutputSettings: buildOutputSettings,
            prepareBatchEnvironment: prepareBatchEnvironment,
            prepareSingleSourceEnvironment: prepareSingleSourceEnvironment,
            validate: { preparedSource, environment in
                await self.validatePreparedSourceOutputSettings(
                    for: kind,
                    source: preparedSource,
                    environment: environment
                )
            },
            runConversion: runConversion
        )
    }

    func makeConversionWorkflowDescriptor<OutputSettings: Sendable>(
        using profile: ConversionWorkflowProfile<OutputSettings>
    ) -> ConversionWorkflowDescriptor<OutputSettings> {
        let prepareSingleSourceEnvironment: (
            @MainActor @Sendable (
                PreparedSourceConversion,
                OutputSettings
            ) async -> BatchExecutionEnvironment
        )?

        if let prepare = profile.prepareSingleSourceEnvironment {
            prepareSingleSourceEnvironment = { preparedSource, outputSettings in
                await prepare(self, preparedSource, outputSettings)
            }
        } else {
            prepareSingleSourceEnvironment = nil
        }

        return makeConversionWorkflowDescriptor(
            kind: profile.kind,
            fileExtension: profile.fileExtension(self),
            metadata: profile.kind.conversionMetadata,
            buildOutputSettings: { try profile.buildOutputSettings(self) },
            prepareBatchEnvironment: { preparedSources, outputSettings in
                await profile.prepareBatchEnvironment(self, preparedSources, outputSettings)
            },
            prepareSingleSourceEnvironment: prepareSingleSourceEnvironment,
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await profile.runConversion(
                    self,
                    preparedSource,
                    environment,
                    outputSettings,
                    index,
                    totalCount
                )
            }
        )
    }

    func videoConversionWorkflowDescriptor() -> ConversionWorkflowDescriptor<VideoOutputSettings> {
        makeConversionWorkflowDescriptor(using: Self.videoConversionWorkflowProfile)
    }

    func imageConversionWorkflowDescriptor() -> ConversionWorkflowDescriptor<ImageOutputSettings> {
        makeConversionWorkflowDescriptor(using: Self.imageConversionWorkflowProfile)
    }

    func audioConversionWorkflowDescriptor() -> ConversionWorkflowDescriptor<AudioOutputSettings> {
        makeConversionWorkflowDescriptor(using: Self.audioConversionWorkflowProfile)
    }

    func performConversion<OutputSettings: Sendable>(
        using workflow: ConversionWorkflowDescriptor<OutputSettings>
    ) async {
        let descriptor = mediaStateDescriptor(for: workflow.kind)

        await performMediaBatchConversion(
            canConvert: workflow.canConvert,
            primarySourceURL: mediaStateValue(using: descriptor, \.sourceURL),
            queuedSourceURLs: mediaStateValue(using: descriptor, \.queuedSourceURLs),
            existingOutputURLsBySourceID: mediaStateValue(
                using: descriptor,
                \.convertedOutputURLsBySourceID
            ),
            missingSourceLog: workflow.metadata.missingSourceLog,
            fileExtension: workflow.fileExtension,
            outputLabel: workflow.metadata.outputLabel,
            preferredOutputDestination: selectedOutputDestinationHandle(for: workflow.kind),
            preferredOutputDirectory: selectedOutputDirectoryURL(for: workflow.kind),
            runningKeyPath: descriptor.isConverting,
            progressKeyPath: descriptor.progress,
            errorMessageKeyPath: descriptor.conversionErrorMessage,
            currentBatchIndexKeyPath: descriptor.currentBatchIndex,
            totalBatchCountKeyPath: descriptor.totalBatchCount,
            skippedSummaryPrefix: workflow.metadata.skippedSummaryPrefix,
            treatExportCancellationAsCancelled: workflow.metadata.treatExportCancellationAsCancelled,
            startState: { outputDirectoryURL, preserveCompletedOutputs in
                self.setSelectedOutputDirectoryURL(outputDirectoryURL, for: workflow.kind)
                self.prepareConversionStartState(
                    for: workflow.kind,
                    preserveCompletedOutputs: preserveCompletedOutputs
                )
            },
            buildOutputSettings: workflow.buildOutputSettings,
            prepareBatchEnvironment: workflow.prepareBatchEnvironment,
            prepareSingleSourceEnvironment: workflow.prepareSingleSourceEnvironment,
            validate: workflow.validate,
            runConversion: workflow.runConversion,
            onSavedOutput: { sourceURL, savedURL in
                self.appendConvertedOutput(savedURL, from: sourceURL, for: workflow.kind)
            },
            onSourceProcessed: { sourceURL in
                self.markProcessedSource(sourceURL, for: workflow.kind)
            },
            onError: { error in
                self.applyConversionError(
                    error,
                    for: workflow.kind,
                    logPrefix: workflow.metadata.errorLogPrefix,
                    treatExportCancellationAsCancelled: workflow.metadata.treatExportCancellationAsCancelled,
                    includeDebugInfo: workflow.metadata.includeDebugInfo
                )
            },
            onSingleSourceCompletion: {
                self.clearPreparedSingleVideoSelection(for: workflow.kind)
            }
        )
    }

    func performMediaBatchConversion<OutputSettings: Sendable>(
        canConvert: Bool,
        primarySourceURL: URL?,
        queuedSourceURLs: [URL],
        existingOutputURLsBySourceID: [String: URL],
        missingSourceLog: String,
        fileExtension: String,
        outputLabel: String,
        preferredOutputDestination: OutputDestinationHandle?,
        preferredOutputDirectory: URL?,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
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

        let allSourceURLs = [primarySourceURL] + queuedSourceURLs
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
                preparedSource: preparedSource,
                outputSettings: outputSettings,
                prepareSingleSourceEnvironment: prepareSingleSourceEnvironment,
                runningKeyPath: runningKeyPath,
                progressKeyPath: progressKeyPath,
                errorMessageKeyPath: errorMessageKeyPath,
                currentBatchIndexKeyPath: currentBatchIndexKeyPath,
                totalBatchCountKeyPath: totalBatchCountKeyPath,
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
            preparedSources: batchContext.preparedSources,
            batchEnvironment: batchEnvironment,
            runningKeyPath: runningKeyPath,
            progressKeyPath: progressKeyPath,
            errorMessageKeyPath: errorMessageKeyPath,
            currentBatchIndexKeyPath: currentBatchIndexKeyPath,
            totalBatchCountKeyPath: totalBatchCountKeyPath,
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
        preparedSource: PreparedSourceConversion,
        outputSettings: OutputSettings,
        prepareSingleSourceEnvironment: @escaping @MainActor (
            PreparedSourceConversion,
            OutputSettings
        ) async -> BatchExecutionEnvironment,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, OutputSettings, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        self[keyPath: totalBatchCountKeyPath] = 1
        self[keyPath: currentBatchIndexKeyPath] = 1

        await performManagedConversionExecution(
            runningKeyPath: runningKeyPath,
            progressKeyPath: progressKeyPath,
            errorMessageKeyPath: errorMessageKeyPath,
            currentBatchIndexKeyPath: currentBatchIndexKeyPath,
            totalBatchCountKeyPath: totalBatchCountKeyPath,
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

            setProgress(1, at: progressKeyPath)
            if let entry = result.skippedEntry {
                onSourceProcessed(preparedSource.sourceURL)
                self[keyPath: errorMessageKeyPath] = BatchConversionSupport.skippedFilesSummary(
                    prefix: skippedSummaryPrefix,
                    entries: [entry]
                )
            } else if let savedURL = result.savedURL {
                onSavedOutput(preparedSource.sourceURL, savedURL)
                onSourceProcessed(preparedSource.sourceURL)
            }
        }
    }
}
