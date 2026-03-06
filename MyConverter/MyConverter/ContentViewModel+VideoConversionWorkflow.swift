import Foundation

extension ContentViewModel {
    func convertVideo() async {
        await performConversion(
            using: ConversionWorkflowDescriptor(
                kind: .video,
                canConvert: canConvert,
                missingSourceLog: "No file to convert.",
                fileExtension: selectedOutputFormat.fileExtension,
                outputLabel: "Video",
                destinationErrorCode: -1001,
                skippedSummaryPrefix: "Some video files were skipped:",
                treatExportCancellationAsCancelled: true,
                errorLogPrefix: "Conversion failed",
                includeDebugInfo: true,
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
                        inputDurationSeconds: nil,
                        onProgress: self.batchProgressHandler(
                            for: .video,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            )
        )
    }
}
