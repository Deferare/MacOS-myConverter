import Foundation

extension ContentViewModel {
    func convertVideo() async {
        await performMediaBatchConversion(
            for: .video,
            canConvert: canConvert,
            missingSourceLog: "No file to convert.",
            fileExtension: selectedOutputFormat.fileExtension,
            outputLabel: "Video",
            destinationErrorCode: -1001,
            skippedSummaryPrefix: "Some video files were skipped:",
            treatExportCancellationAsCancelled: true,
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
                    await self.updateBatchProgress(
                        for: .video,
                        itemProgress: progress,
                        index: index,
                        totalCount: totalCount
                    )
                }
            },
            onError: {
                self.applyConversionError(
                    $0,
                    for: .video,
                    logPrefix: "Conversion failed",
                    treatExportCancellationAsCancelled: true,
                    includeDebugInfo: true
                )
            }
        )
    }
}
