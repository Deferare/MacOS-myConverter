import Foundation

extension ContentViewModel {
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
}
