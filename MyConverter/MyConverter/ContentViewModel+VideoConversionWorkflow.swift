import Foundation

extension ContentViewModel {
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
            onSourceProcessed: { _ in },
            onError: applyConversionError(_:)
        )
    }
}
