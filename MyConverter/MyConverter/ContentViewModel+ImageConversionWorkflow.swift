import Foundation

extension ContentViewModel {
    func convertImage() async {
        await performConversion(
            using: ConversionWorkflowDescriptor(
                kind: .image,
                canConvert: canStartConversion(for: .image, validationMessage: validationMessage(for: .image)),
                missingSourceLog: "No image file to convert.",
                fileExtension: selectedImageOutputFormat.fileExtension,
                outputLabel: "Image",
                destinationErrorCode: -1002,
                skippedSummaryPrefix: "Some image files were skipped:",
                treatExportCancellationAsCancelled: false,
                errorLogPrefix: "Image conversion failed",
                includeDebugInfo: false,
                buildOutputSettings: { self.buildImageOutputSettings() },
                validate: { await self.validateSourceOutputSettings(for: .image, sourceURL: $0) },
                makeWorkingOutputURL: { sourceURL in
                    ImageConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedImageOutputFormat)
                },
                runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                    try await ImageConversionEngine.convert(
                        inputURL: sourceURL,
                        outputURL: workingOutputURL,
                        outputSettings: outputSettings,
                        onProgress: self.batchProgressHandler(
                            for: .image,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            )
        )
    }
}
