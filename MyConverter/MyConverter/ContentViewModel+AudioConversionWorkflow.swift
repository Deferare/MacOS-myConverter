import Foundation

extension ContentViewModel {
    func convertAudio() async {
        await performMediaBatchConversion(
            for: .audio,
            canConvert: canConvertAudio,
            missingSourceLog: "No audio file to convert.",
            fileExtension: selectedAudioOutputFormat.fileExtension,
            outputLabel: "Audio",
            destinationErrorCode: -1003,
            skippedSummaryPrefix: "Some audio files were skipped:",
            treatExportCancellationAsCancelled: true,
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
                    await self.updateBatchProgress(
                        for: .audio,
                        itemProgress: progress,
                        index: index,
                        totalCount: totalCount
                    )
                }
            },
            onError: {
                self.applyConversionError(
                    $0,
                    for: .audio,
                    logPrefix: "Audio conversion failed",
                    treatExportCancellationAsCancelled: true
                )
            }
        )
    }
}
