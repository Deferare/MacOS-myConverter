import Foundation

extension ContentViewModel {
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
            onSourceProcessed: { _ in },
            onError: applyAudioConversionError(_:)
        )
    }
}
