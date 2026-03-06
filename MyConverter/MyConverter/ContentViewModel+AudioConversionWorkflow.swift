import Foundation

extension ContentViewModel {
    func convertAudio() async {
        await performConversion(
            using: ConversionWorkflowDescriptor(
                kind: .audio,
                canConvert: canStartConversion(for: .audio, validationMessage: validationMessage(for: .audio)),
                missingSourceLog: "No audio file to convert.",
                fileExtension: selectedAudioOutputFormat.fileExtension,
                outputLabel: "Audio",
                destinationErrorCode: -1003,
                skippedSummaryPrefix: "Some audio files were skipped:",
                treatExportCancellationAsCancelled: true,
                errorLogPrefix: "Audio conversion failed",
                includeDebugInfo: false,
                buildOutputSettings: { self.buildAudioOutputSettings() },
                validate: { await self.validateSourceOutputSettings(for: .audio, sourceURL: $0) },
                makeWorkingOutputURL: { sourceURL in
                    VideoConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedAudioOutputFormat)
                },
                runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                    try await VideoConversionEngine.convertAudio(
                        inputURL: sourceURL,
                        outputURL: workingOutputURL,
                        outputSettings: outputSettings,
                        inputDurationSeconds: nil,
                        onProgress: self.batchProgressHandler(
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
