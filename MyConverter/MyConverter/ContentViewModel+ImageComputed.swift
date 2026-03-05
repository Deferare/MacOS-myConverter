import Foundation

extension ContentViewModel {
    // MARK: - Image Computed Properties

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
        selectedImageSourceURLs.count
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

    var imageOutputFormatOptions: [ImageFormatOption] {
        defaultedOutputFormats(sourceURL: imageSourceURL, availableFormats: availableImageOutputFormats) {
            ImageConversionEngine.defaultOutputFormats()
        }
    }

    var isImageSettingsValid: Bool {
        imageSettingsValidationMessage == nil
    }

    var shouldShowImageQualityOption: Bool {
        selectedImageOutputFormat.supportsCompressionQuality
    }

    var shouldShowPNGCompressionOption: Bool {
        selectedImageOutputFormat.supportsPNGCompressionLevel
    }

    var shouldShowPreserveAnimationOption: Bool {
        imageSourceIsAnimated && selectedImageOutputFormat.supportsAnimation
    }

    var imageFormatHintMessage: String? {
        if imageSourceIsAnimated && !selectedImageOutputFormat.supportsAnimation {
            return "This format exports only the first frame for animated sources."
        }
        if shouldShowPreserveAnimationOption && !ImageConversionEngine.isFFmpegAvailable() {
            return "ffmpeg is required to preserve animation."
        }
        return nil
    }

    var imageSettingsValidationMessage: String? {
        if let imageSourceCompatibilityErrorMessage {
            return imageSourceCompatibilityErrorMessage
        }
        if imageSourceURL != nil && !availableImageOutputFormats.contains(where: { $0.normalizedID == selectedImageOutputFormat.normalizedID }) {
            return "Selected output format is not available for this source."
        }
        if imageSourceIsAnimated &&
            preserveImageAnimation &&
            selectedImageOutputFormat.supportsAnimation &&
            !ImageConversionEngine.isFFmpegAvailable() {
            return "Animated output requires ffmpeg for the selected format."
        }
        return nil
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
