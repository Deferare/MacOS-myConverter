import Foundation

extension ContentViewModel {
    struct ConversionWorkflowDescriptor<OutputSettings> {
        let kind: MediaKind
        let canConvert: Bool
        let missingSourceLog: String
        let fileExtension: String
        let outputLabel: String
        let destinationErrorCode: Int
        let skippedSummaryPrefix: String
        let treatExportCancellationAsCancelled: Bool
        let errorLogPrefix: String
        let includeDebugInfo: Bool
        let buildOutputSettings: () throws -> OutputSettings
        let validate: (URL) async -> String?
        let makeWorkingOutputURL: (URL) -> URL
        let runConversion: (URL, URL, OutputSettings, Int, Int) async throws -> URL
    }

    struct ConversionExecutionDescriptor {
        let execute: @MainActor (ContentViewModel) async -> Void
    }

    func conversionExecutionDescriptor(for kind: MediaKind) -> ConversionExecutionDescriptor {
        switch kind {
        case .video:
            return ConversionExecutionDescriptor { viewModel in
                await viewModel.performConversion(
                    using: ConversionWorkflowDescriptor(
                        kind: .video,
                        canConvert: viewModel.canStartConversion(
                            for: .video,
                            validationMessage: viewModel.validationMessage(for: .video)
                        ),
                        missingSourceLog: "No file to convert.",
                        fileExtension: viewModel.selectedOutputFormat.fileExtension,
                        outputLabel: "Video",
                        destinationErrorCode: -1001,
                        skippedSummaryPrefix: "Some video files were skipped:",
                        treatExportCancellationAsCancelled: true,
                        errorLogPrefix: "Conversion failed",
                        includeDebugInfo: true,
                        buildOutputSettings: { try viewModel.buildVideoOutputSettings() },
                        validate: { await viewModel.validateSourceOutputSettings(for: .video, sourceURL: $0) },
                        makeWorkingOutputURL: { sourceURL in
                            VideoConversionEngine.temporaryOutputURL(
                                for: sourceURL,
                                format: viewModel.selectedOutputFormat
                            )
                        },
                        runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                            try await VideoConversionEngine.convert(
                                inputURL: sourceURL,
                                outputURL: workingOutputURL,
                                outputSettings: outputSettings,
                                inputDurationSeconds: nil,
                                onProgress: viewModel.batchProgressHandler(
                                    for: .video,
                                    index: index,
                                    totalCount: totalCount
                                )
                            )
                        }
                    )
                )
            }
        case .image:
            return ConversionExecutionDescriptor { viewModel in
                await viewModel.performConversion(
                    using: ConversionWorkflowDescriptor(
                        kind: .image,
                        canConvert: viewModel.canStartConversion(
                            for: .image,
                            validationMessage: viewModel.validationMessage(for: .image)
                        ),
                        missingSourceLog: "No image file to convert.",
                        fileExtension: viewModel.selectedImageOutputFormat.fileExtension,
                        outputLabel: "Image",
                        destinationErrorCode: -1002,
                        skippedSummaryPrefix: "Some image files were skipped:",
                        treatExportCancellationAsCancelled: false,
                        errorLogPrefix: "Image conversion failed",
                        includeDebugInfo: false,
                        buildOutputSettings: { viewModel.buildImageOutputSettings() },
                        validate: { await viewModel.validateSourceOutputSettings(for: .image, sourceURL: $0) },
                        makeWorkingOutputURL: { sourceURL in
                            ImageConversionEngine.temporaryOutputURL(
                                for: sourceURL,
                                format: viewModel.selectedImageOutputFormat
                            )
                        },
                        runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                            try await ImageConversionEngine.convert(
                                inputURL: sourceURL,
                                outputURL: workingOutputURL,
                                outputSettings: outputSettings,
                                onProgress: viewModel.batchProgressHandler(
                                    for: .image,
                                    index: index,
                                    totalCount: totalCount
                                )
                            )
                        }
                    )
                )
            }
        case .audio:
            return ConversionExecutionDescriptor { viewModel in
                await viewModel.performConversion(
                    using: ConversionWorkflowDescriptor(
                        kind: .audio,
                        canConvert: viewModel.canStartConversion(
                            for: .audio,
                            validationMessage: viewModel.validationMessage(for: .audio)
                        ),
                        missingSourceLog: "No audio file to convert.",
                        fileExtension: viewModel.selectedAudioOutputFormat.fileExtension,
                        outputLabel: "Audio",
                        destinationErrorCode: -1003,
                        skippedSummaryPrefix: "Some audio files were skipped:",
                        treatExportCancellationAsCancelled: true,
                        errorLogPrefix: "Audio conversion failed",
                        includeDebugInfo: false,
                        buildOutputSettings: { viewModel.buildAudioOutputSettings() },
                        validate: { await viewModel.validateSourceOutputSettings(for: .audio, sourceURL: $0) },
                        makeWorkingOutputURL: { sourceURL in
                            VideoConversionEngine.temporaryOutputURL(
                                for: sourceURL,
                                format: viewModel.selectedAudioOutputFormat
                            )
                        },
                        runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                            try await VideoConversionEngine.convertAudio(
                                inputURL: sourceURL,
                                outputURL: workingOutputURL,
                                outputSettings: outputSettings,
                                inputDurationSeconds: nil,
                                onProgress: viewModel.batchProgressHandler(
                                    for: .audio,
                                    index: index,
                                    totalCount: totalCount
                                )
                            )
                        }
                    )
                )
            }
        }
    }

    func performConversion<OutputSettings>(
        using workflow: ConversionWorkflowDescriptor<OutputSettings>
    ) async {
        let descriptor = mediaStateDescriptor(for: workflow.kind)

        await performMediaBatchConversion(
            canConvert: workflow.canConvert,
            primarySourceURL: self[keyPath: descriptor.sourceURL],
            queuedSourceURLs: self[keyPath: descriptor.queuedSourceURLs],
            missingSourceLog: workflow.missingSourceLog,
            fileExtension: workflow.fileExtension,
            outputLabel: workflow.outputLabel,
            destinationErrorCode: workflow.destinationErrorCode,
            runningKeyPath: descriptor.isConverting,
            progressKeyPath: descriptor.progress,
            errorMessageKeyPath: descriptor.conversionErrorMessage,
            currentBatchIndexKeyPath: descriptor.currentBatchIndex,
            totalBatchCountKeyPath: descriptor.totalBatchCount,
            skippedSummaryPrefix: workflow.skippedSummaryPrefix,
            treatExportCancellationAsCancelled: workflow.treatExportCancellationAsCancelled,
            startState: { self.prepareConversionStartState(for: workflow.kind) },
            buildOutputSettings: workflow.buildOutputSettings,
            validate: workflow.validate,
            makeWorkingOutputURL: workflow.makeWorkingOutputURL,
            runConversion: workflow.runConversion,
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(savedURL, for: workflow.kind)
            },
            onSourceProcessed: { _ in },
            onError: { error in
                self.applyConversionError(
                    error,
                    for: workflow.kind,
                    logPrefix: workflow.errorLogPrefix,
                    treatExportCancellationAsCancelled: workflow.treatExportCancellationAsCancelled,
                    includeDebugInfo: workflow.includeDebugInfo
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
        onSavedOutput: @escaping (URL) -> Void,
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
            outputLabel: outputLabel
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
