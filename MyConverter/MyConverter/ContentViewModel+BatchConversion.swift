import Foundation

extension ContentViewModel {
    struct ConversionWorkflowDescriptor<OutputSettings: Sendable> {
        let kind: MediaKind
        let canConvert: Bool
        let fileExtension: String
        let metadata: ConversionMetadata
        let buildOutputSettings: () throws -> OutputSettings
        let prepareBatchEnvironment: @Sendable ([PreparedSourceConversion], OutputSettings, URL) async -> BatchExecutionEnvironment
        let prepareSingleSourceEnvironment: (@MainActor (PreparedSourceConversion, OutputSettings, URL) async -> BatchExecutionEnvironment)?
        let validate: (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?
        let runConversion: (PreparedSourceConversion, BatchExecutionEnvironment, OutputSettings, Int, Int) async throws -> URL
    }

    struct ConversionExecutionDescriptor {
        let execute: @MainActor (ContentViewModel) async -> Void
    }

    func makeConversionExecutionDescriptor<OutputSettings: Sendable>(
        workflow: @escaping (ContentViewModel) -> ConversionWorkflowDescriptor<OutputSettings>
    ) -> ConversionExecutionDescriptor {
        ConversionExecutionDescriptor { viewModel in
            await viewModel.performConversion(using: workflow(viewModel))
        }
    }

    func makeConversionWorkflowDescriptor<OutputSettings: Sendable>(
        kind: MediaKind,
        fileExtension: String,
        metadata: ConversionMetadata,
        buildOutputSettings: @escaping () throws -> OutputSettings,
        prepareBatchEnvironment: @escaping @Sendable ([PreparedSourceConversion], OutputSettings, URL) async -> BatchExecutionEnvironment,
        prepareSingleSourceEnvironment: (@MainActor (PreparedSourceConversion, OutputSettings, URL) async -> BatchExecutionEnvironment)? = nil,
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

    func videoConversionWorkflowDescriptor() -> ConversionWorkflowDescriptor<VideoOutputSettings> {
        let kind: MediaKind = .video
        return makeConversionWorkflowDescriptor(
            kind: kind,
            fileExtension: selectedOutputFormatFileExtension(using: videoOutputFormatDescriptor()),
            metadata: kind.conversionMetadata,
            buildOutputSettings: { try self.buildVideoOutputSettings() },
            prepareBatchEnvironment: { preparedSources, outputSettings, outputDirectoryURL in
                await ContentViewModel.prepareVideoBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    outputSettings: outputSettings,
                    outputDirectoryURL: outputDirectoryURL
                )
            },
            prepareSingleSourceEnvironment: { preparedSource, outputSettings, outputDirectoryURL in
                await self.prepareSingleVideoBatchExecutionEnvironment(
                    preparedSource: preparedSource,
                    outputSettings: outputSettings,
                    outputDirectoryURL: outputDirectoryURL
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
                        for: kind,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func imageConversionWorkflowDescriptor() -> ConversionWorkflowDescriptor<ImageOutputSettings> {
        let kind: MediaKind = .image
        return makeConversionWorkflowDescriptor(
            kind: kind,
            fileExtension: selectedOutputFormatFileExtension(using: imageOutputFormatDescriptor()),
            metadata: kind.conversionMetadata,
            buildOutputSettings: { self.buildImageOutputSettings() },
            prepareBatchEnvironment: { preparedSources, _, outputDirectoryURL in
                await ContentViewModel.prepareImageBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    outputDirectoryURL: outputDirectoryURL
                )
            },
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await ImageConversionEngine.convert(
                    inputURL: preparedSource.sourceURL,
                    outputURL: preparedSource.workingOutputURL,
                    outputSettings: outputSettings,
                    ffmpegContext: environment.imageFFmpegContext,
                    onProgress: self.batchProgressHandler(
                        for: kind,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func audioConversionWorkflowDescriptor() -> ConversionWorkflowDescriptor<AudioOutputSettings> {
        let kind: MediaKind = .audio
        return makeConversionWorkflowDescriptor(
            kind: kind,
            fileExtension: selectedOutputFormatFileExtension(using: audioOutputFormatDescriptor()),
            metadata: kind.conversionMetadata,
            buildOutputSettings: { self.buildAudioOutputSettings() },
            prepareBatchEnvironment: { preparedSources, _, outputDirectoryURL in
                await ContentViewModel.prepareAudioBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    outputDirectoryURL: outputDirectoryURL
                )
            },
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await VideoConversionEngine.convertAudio(
                    inputURL: preparedSource.sourceURL,
                    outputURL: preparedSource.workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil,
                    ffmpegContext: environment.videoFFmpegContext,
                    onProgress: self.batchProgressHandler(
                        for: kind,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func performConversion<OutputSettings: Sendable>(
        using workflow: ConversionWorkflowDescriptor<OutputSettings>
    ) async {
        let descriptor = mediaStateDescriptor(for: workflow.kind)

        await performMediaBatchConversion(
            canConvert: workflow.canConvert,
            primarySourceURL: mediaStateValue(using: descriptor, \.sourceURL),
            queuedSourceURLs: mediaStateValue(using: descriptor, \.queuedSourceURLs),
            missingSourceLog: workflow.metadata.missingSourceLog,
            fileExtension: workflow.fileExtension,
            outputLabel: workflow.metadata.outputLabel,
            preferredOutputDirectory: selectedOutputDirectoryURL(for: workflow.kind),
            runningKeyPath: descriptor.isConverting,
            progressKeyPath: descriptor.progress,
            errorMessageKeyPath: descriptor.conversionErrorMessage,
            currentBatchIndexKeyPath: descriptor.currentBatchIndex,
            totalBatchCountKeyPath: descriptor.totalBatchCount,
            skippedSummaryPrefix: workflow.metadata.skippedSummaryPrefix,
            treatExportCancellationAsCancelled: workflow.metadata.treatExportCancellationAsCancelled,
            startState: { outputDirectoryURL in
                self.setSelectedOutputDirectoryURL(outputDirectoryURL, for: workflow.kind)
                self.prepareConversionStartState(for: workflow.kind)
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
        missingSourceLog: String,
        fileExtension: String,
        outputLabel: String,
        preferredOutputDirectory: URL?,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        startState: (URL) -> Void,
        buildOutputSettings: () throws -> OutputSettings,
        prepareBatchEnvironment: @escaping @Sendable ([PreparedSourceConversion], OutputSettings, URL) async -> BatchExecutionEnvironment,
        prepareSingleSourceEnvironment: (@MainActor (PreparedSourceConversion, OutputSettings, URL) async -> BatchExecutionEnvironment)? = nil,
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

        let sourceURLs = [primarySourceURL] + queuedSourceURLs
        let resolvedOutputDirectoryURL: URL
        if let preferredOutputDirectory {
            resolvedOutputDirectoryURL = preferredOutputDirectory.standardizedFileURL
        } else {
            guard let selectedDirectory = BatchConversionSupport.presentBatchDirectoryAccessPanel(
                suggestedDirectory: primarySourceURL.deletingLastPathComponent(),
                outputLabel: outputLabel,
                fileCount: sourceURLs.count
            ) else {
                return
            }
            resolvedOutputDirectoryURL = selectedDirectory.standardizedFileURL
        }

        let batchContextTask = Task.detached(priority: .userInitiated) {
            BatchConversionSupport.prepareContext(
                sourceURLs: sourceURLs,
                fileExtension: fileExtension,
                outputDirectoryURL: resolvedOutputDirectoryURL
            )
        }
        let batchContext = await withTaskCancellationHandler(
            operation: {
                await batchContextTask.value
            },
            onCancel: {
                batchContextTask.cancel()
            }
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

        startState(batchContext.outputDirectoryURL)
        if batchContext.preparedSources.count == 1,
           let preparedSource = batchContext.preparedSources.first,
           let prepareSingleSourceEnvironment {
            defer { onSingleSourceCompletion?() }
            await executeSingleSourceConversion(
                preparedSource: preparedSource,
                outputSettings: outputSettings,
                outputDirectoryURL: batchContext.outputDirectoryURL,
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

        let batchEnvironmentTask = Task.detached(priority: .userInitiated) {
            await prepareBatchEnvironment(
                batchContext.preparedSources,
                outputSettings,
                batchContext.outputDirectoryURL
            )
        }
        let batchEnvironment = await withTaskCancellationHandler(
            operation: {
                await batchEnvironmentTask.value
            },
            onCancel: {
                batchEnvironmentTask.cancel()
            }
        )
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
        outputDirectoryURL: URL,
        prepareSingleSourceEnvironment: @escaping @MainActor (
            PreparedSourceConversion,
            OutputSettings,
            URL
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

        do {
            defer {
                self[keyPath: runningKeyPath] = false
                self[keyPath: currentBatchIndexKeyPath] = 0
                self[keyPath: totalBatchCountKeyPath] = 0
            }
            try Task.checkCancellation()

            let batchEnvironment = await prepareSingleSourceEnvironment(
                preparedSource,
                outputSettings,
                outputDirectoryURL
            )

            let result = try await withSourceSecurityScope(for: preparedSource.sourceURL) {
                if let validationMessage = await validate(preparedSource, batchEnvironment) {
                    onSourceProcessed(preparedSource.sourceURL)
                    return (
                        savedURL: Optional<URL>.none,
                        skippedEntry: Optional(
                            "\(preparedSource.sourceURL.lastPathComponent): \(validationMessage)"
                        )
                    )
                }

                defer {
                    BatchConversionSupport.cleanupWorkingOutputIfNeeded(
                        preparedSource.workingOutputURL
                    )
                }

                let output = try await runConversion(
                    preparedSource,
                    batchEnvironment,
                    outputSettings,
                    0,
                    1
                )
                try Task.checkCancellation()

                let savedURL = try BatchConversionSupport.savePreparedConvertedOutput(
                    from: output,
                    preparedSource: preparedSource
                )
                return (
                    savedURL: Optional(savedURL),
                    skippedEntry: Optional<String>.none
                )
            }

            setProgress(1, at: progressKeyPath)
            if let entry = result.skippedEntry {
                self[keyPath: errorMessageKeyPath] = BatchConversionSupport.skippedFilesSummary(
                    prefix: skippedSummaryPrefix,
                    entries: [entry]
                )
            } else if let savedURL = result.savedURL {
                onSavedOutput(preparedSource.sourceURL, savedURL)
                onSourceProcessed(preparedSource.sourceURL)
            }
        } catch is CancellationError {
            setProgress(0, at: progressKeyPath)
            self[keyPath: errorMessageKeyPath] = nil
        } catch ConversionError.exportCancelled where treatExportCancellationAsCancelled {
            setProgress(0, at: progressKeyPath)
            self[keyPath: errorMessageKeyPath] = nil
        } catch {
            onError(error)
        }
    }
}
