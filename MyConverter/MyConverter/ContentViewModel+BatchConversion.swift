import Foundation

extension ContentViewModel {
    struct ConversionWorkflowDescriptor<OutputSettings> {
        let kind: MediaKind
        let canConvert: Bool
        let fileExtension: String
        let metadata: ConversionMetadata
        let buildOutputSettings: () throws -> OutputSettings
        let validate: (URL) async -> String?
        let makeWorkingOutputURL: (URL) -> URL
        let runConversion: (URL, URL, OutputSettings, Int, Int) async throws -> URL
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
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, OutputSettings, Int, Int) async throws -> URL
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
            validate: { await self.validateSourceOutputSettings(for: kind, sourceURL: $0) },
            makeWorkingOutputURL: makeWorkingOutputURL,
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
            makeWorkingOutputURL: { sourceURL in
                VideoConversionEngine.temporaryOutputURL(
                    for: sourceURL,
                    format: self.selectedOutputFormat
                )
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await VideoConversionEngine.convert(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil,
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
            makeWorkingOutputURL: { sourceURL in
                ImageConversionEngine.temporaryOutputURL(
                    for: sourceURL,
                    format: self.selectedImageOutputFormat
                )
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await ImageConversionEngine.convert(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
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
            makeWorkingOutputURL: { sourceURL in
                VideoConversionEngine.temporaryOutputURL(
                    for: sourceURL,
                    format: self.selectedAudioOutputFormat
                )
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await VideoConversionEngine.convertAudio(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil,
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
            destinationErrorCode: workflow.metadata.destinationErrorCode,
            runningKeyPath: descriptor.isConverting,
            progressKeyPath: descriptor.progress,
            errorMessageKeyPath: descriptor.conversionErrorMessage,
            currentBatchIndexKeyPath: descriptor.currentBatchIndex,
            totalBatchCountKeyPath: descriptor.totalBatchCount,
            skippedSummaryPrefix: workflow.metadata.skippedSummaryPrefix,
            treatExportCancellationAsCancelled: workflow.metadata.treatExportCancellationAsCancelled,
            startState: { self.prepareConversionStartState(for: workflow.kind) },
            buildOutputSettings: workflow.buildOutputSettings,
            validate: workflow.validate,
            makeWorkingOutputURL: workflow.makeWorkingOutputURL,
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
        destinationErrorCode: Int,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        startState: () -> Void,
        buildOutputSettings: () throws -> OutputSettings,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, OutputSettings, Int, Int) async throws -> URL,
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

        let sourceURLs = batchContext.sourceURLs
        let destinationURLsBySourceID = batchContext.destinationURLsBySourceID
        defer { batchContext.stopAccessingBatchDirectory() }

        do {
            try Task.checkCancellation()
        } catch {
            return
        }

        startState()
        await executeBatchConversion(
            sourceURLs: sourceURLs,
            destinationURLsBySourceID: destinationURLsBySourceID,
            destinationErrorCode: destinationErrorCode,
            runningKeyPath: runningKeyPath,
            progressKeyPath: progressKeyPath,
            errorMessageKeyPath: errorMessageKeyPath,
            currentBatchIndexKeyPath: currentBatchIndexKeyPath,
            totalBatchCountKeyPath: totalBatchCountKeyPath,
            skippedSummaryPrefix: skippedSummaryPrefix,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            validate: validate,
            makeWorkingOutputURL: makeWorkingOutputURL,
            runConversion: { sourceURL, workingOutputURL, index, totalCount in
                try await runConversion(sourceURL, workingOutputURL, outputSettings, index, totalCount)
            },
            onSavedOutput: onSavedOutput,
            onSourceProcessed: onSourceProcessed,
            onError: onError
        )
    }
}
