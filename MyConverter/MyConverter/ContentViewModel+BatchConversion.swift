import Foundation

extension ContentViewModel {
    struct ConversionWorkflowDescriptor<OutputSettings> {
        let kind: MediaKind
        let canConvert: Bool
        let fileExtension: String
        let metadata: ConversionMetadata
        let buildOutputSettings: () throws -> OutputSettings
        let prepareBatchEnvironment: ([PreparedSourceConversion], OutputSettings, URL) async -> BatchExecutionEnvironment
        let validate: (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?
        let runConversion: (PreparedSourceConversion, BatchExecutionEnvironment, OutputSettings, Int, Int) async throws -> URL
    }

    struct ConversionExecutionDescriptor {
        let execute: @MainActor (ContentViewModel) async -> Void
    }

    func makeConversionExecutionDescriptor<OutputSettings>(
        workflow: @escaping (ContentViewModel) -> ConversionWorkflowDescriptor<OutputSettings>
    ) -> ConversionExecutionDescriptor {
        ConversionExecutionDescriptor { viewModel in
            await viewModel.performConversion(using: workflow(viewModel))
        }
    }

    func makeConversionWorkflowDescriptor<OutputSettings>(
        kind: MediaKind,
        fileExtension: String,
        metadata: ConversionMetadata,
        buildOutputSettings: @escaping () throws -> OutputSettings,
        prepareBatchEnvironment: @escaping ([PreparedSourceConversion], OutputSettings, URL) async -> BatchExecutionEnvironment,
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
                await self.prepareVideoBatchExecutionEnvironment(
                    preparedSources: preparedSources,
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
                await self.prepareImageBatchExecutionEnvironment(
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
                await self.prepareAudioBatchExecutionEnvironment(
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

    func performConversion<OutputSettings>(
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
            }
        )
    }

    func performMediaBatchConversion<OutputSettings>(
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
        prepareBatchEnvironment: @escaping ([PreparedSourceConversion], OutputSettings, URL) async -> BatchExecutionEnvironment,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, OutputSettings, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
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

        guard let batchContext = prepareBatchContext(
            primarySourceURL: primarySourceURL,
            queuedSourceURLs: queuedSourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel,
            preferredOutputDirectory: preferredOutputDirectory
        ) else {
            return
        }

        defer { batchContext.stopAccessingBatchDirectory() }

        do {
            try Task.checkCancellation()
        } catch {
            return
        }

        startState(batchContext.outputDirectoryURL)
        let batchEnvironment = await prepareBatchEnvironment(
            batchContext.preparedSources,
            outputSettings,
            batchContext.outputDirectoryURL
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
}
