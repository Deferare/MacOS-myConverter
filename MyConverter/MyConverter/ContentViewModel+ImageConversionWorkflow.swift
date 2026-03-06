import Foundation

extension ContentViewModel {
    func convertImage() async {
        await performMediaBatchConversion(
            for: .image,
            canConvert: canConvertImage,
            missingSourceLog: "No image file to convert.",
            fileExtension: selectedImageOutputFormat.fileExtension,
            outputLabel: "Image",
            destinationErrorCode: -1002,
            skippedSummaryPrefix: "Some image files were skipped:",
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
                    await self.updateBatchProgress(
                        for: .image,
                        itemProgress: progress,
                        index: index,
                        totalCount: totalCount
                    )
                }
            },
            onError: {
                self.applyConversionError(
                    $0,
                    for: .image,
                    logPrefix: "Image conversion failed"
                )
            }
        )
    }
}
