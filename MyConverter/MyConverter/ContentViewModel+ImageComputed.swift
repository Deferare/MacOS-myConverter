import Foundation

extension ContentViewModel {
    var imageSourceIsAnimated: Bool {
        imageSourceFrameCount > 1
    }

    var canConvertImage: Bool {
        canStartConversion(
            sourceURL: imageSourceURL,
            isConverting: isImageConverting,
            isAnalyzingSource: isAnalyzingImageSource,
            validationMessage: imageSettingsValidationMessage,
            selectedFormatAvailable: availableImageOutputFormats.contains(where: { $0.normalizedID == selectedImageOutputFormat.normalizedID })
        )
    }

    var selectedImageSourceURLs: [URL] {
        guard let imageSourceURL else { return [] }
        return [imageSourceURL] + queuedImageSourceURLs
    }

    var selectedImageFileCount: Int {
        imageSourceURL == nil ? 0 : queuedImageSourceURLs.count + 1
    }

    var displayedImageConversionProgress: Double {
        displayedProgress(isConverting: isImageConverting, rawProgress: imageConversionProgress)
    }

    var imageProgressPercentageText: String {
        progressPercentageText(for: displayedImageConversionProgress)
    }

    var imageConversionStatusMessage: String {
        imageConversionStatus.message
    }

    var imageConversionStatusLevel: ConversionStatusLevel {
        imageConversionStatus.level
    }

    private var imageConversionStatus: (message: String, level: ConversionStatusLevel) {
        buildConversionStatus(
            isConverting: isImageConverting,
            currentBatchIndex: currentImageBatchIndex,
            totalBatchCount: totalImageBatchCount,
            isAnalyzingSource: isAnalyzingImageSource,
            conversionErrorMessage: imageConversionErrorMessage,
            validationMessage: imageSettingsValidationMessage,
            compatibilityWarningMessage: imageSourceCompatibilityWarningMessage,
            hintMessage: imageFormatHintMessage
        )
    }
}
