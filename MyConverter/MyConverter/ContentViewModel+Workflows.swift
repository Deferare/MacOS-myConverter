import Foundation

extension ContentViewModel {
    // MARK: - Video Convert

    func convert() async {
        defer { conversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvert,
            primarySourceURL: sourceURL,
            queuedSourceURLs: queuedSourceURLs,
            missingSourceLog: "No file to convert.",
            fileExtension: selectedOutputFormat.fileExtension,
            outputLabel: "Video",
            destinationErrorCode: -1001,
            runningKeyPath: \.isConverting,
            progressKeyPath: \.conversionProgress,
            errorMessageKeyPath: \.conversionErrorMessage,
            currentBatchIndexKeyPath: \.currentVideoBatchIndex,
            totalBatchCountKeyPath: \.totalVideoBatchCount,
            skippedSummaryPrefix: "Some video files were skipped:",
            treatExportCancellationAsCancelled: true,
            startState: { self.prepareConversionStartState() },
            buildOutputSettings: { try self.buildVideoOutputSettings() },
            validate: { await self.validateVideoOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                VideoConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await VideoConversionEngine.convert(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedURL,
                    outputsKeyPath: \.convertedURLs
                )
            },
            onSourceProcessed: removeProcessedVideoSource(_:),
            onError: applyConversionError(_:)
        )
    }

    // MARK: - Image Convert

    func convertImage() async {
        defer { imageConversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvertImage,
            primarySourceURL: imageSourceURL,
            queuedSourceURLs: queuedImageSourceURLs,
            missingSourceLog: "No image file to convert.",
            fileExtension: selectedImageOutputFormat.fileExtension,
            outputLabel: "Image",
            destinationErrorCode: -1002,
            runningKeyPath: \.isImageConverting,
            progressKeyPath: \.imageConversionProgress,
            errorMessageKeyPath: \.imageConversionErrorMessage,
            currentBatchIndexKeyPath: \.currentImageBatchIndex,
            totalBatchCountKeyPath: \.totalImageBatchCount,
            skippedSummaryPrefix: "Some image files were skipped:",
            startState: { self.prepareImageConversionStartState() },
            buildOutputSettings: { self.buildImageOutputSettings() },
            validate: { await self.validateImageOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                ImageConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedImageOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await ImageConversionEngine.convert(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateImageConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedImageURL,
                    outputsKeyPath: \.convertedImageURLs
                )
            },
            onSourceProcessed: removeProcessedImageSource(_:),
            onError: applyImageConversionError(_:)
        )
    }

    // MARK: - Audio Convert

    func convertAudio() async {
        defer { audioConversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvertAudio,
            primarySourceURL: audioSourceURL,
            queuedSourceURLs: queuedAudioSourceURLs,
            missingSourceLog: "No audio file to convert.",
            fileExtension: selectedAudioOutputFormat.fileExtension,
            outputLabel: "Audio",
            destinationErrorCode: -1003,
            runningKeyPath: \.isAudioConverting,
            progressKeyPath: \.audioConversionProgress,
            errorMessageKeyPath: \.audioConversionErrorMessage,
            currentBatchIndexKeyPath: \.currentAudioBatchIndex,
            totalBatchCountKeyPath: \.totalAudioBatchCount,
            skippedSummaryPrefix: "Some audio files were skipped:",
            treatExportCancellationAsCancelled: true,
            startState: { self.prepareAudioConversionStartState() },
            buildOutputSettings: { self.buildAudioOutputSettings() },
            validate: { await self.validateAudioOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                VideoConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedAudioOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await VideoConversionEngine.convertAudio(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateAudioConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedAudioURL,
                    outputsKeyPath: \.convertedAudioURLs
                )
            },
            onSourceProcessed: removeProcessedAudioSource(_:),
            onError: applyAudioConversionError(_:)
        )
    }

    // MARK: - Progress

    func setProgress(_ rawProgress: Double, at keyPath: ReferenceWritableKeyPath<ContentViewModel, Double>) {
        self[keyPath: keyPath] = clampedProgress(rawProgress)
    }

    func normalizedBatchProgress(
        itemProgress: Double,
        index: Int,
        totalCount: Int
    ) -> Double {
        let base = Double(index)
        let total = Double(max(totalCount, 1))
        return (base + itemProgress) / total
    }

    func updateConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.conversionProgress)
    }

    func updateImageConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.imageConversionProgress)
    }

    func updateAudioConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.audioConversionProgress)
    }
}
