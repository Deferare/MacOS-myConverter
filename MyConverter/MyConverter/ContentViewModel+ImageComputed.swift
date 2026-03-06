import Foundation

extension ContentViewModel {
    var imageSourceIsAnimated: Bool {
        imageSourceFrameCount > 1
    }

    var canConvertImage: Bool {
        canStartConversion(
            for: .image,
            validationMessage: imageSettingsValidationMessage,
            selectedFormatAvailable: availableImageOutputFormats.contains(where: { $0.normalizedID == selectedImageOutputFormat.normalizedID })
        )
    }

    var selectedImageSourceURLs: [URL] {
        selectedSourceURLs(for: .image)
    }

    var selectedImageFileCount: Int {
        selectedFileCount(for: .image)
    }

    var displayedImageConversionProgress: Double {
        displayedProgress(for: .image)
    }

    var imageProgressPercentageText: String {
        progressPercentageText(for: .image)
    }

    var imageConversionStatusMessage: String {
        imageConversionStatus.message
    }

    var imageConversionStatusLevel: ConversionStatusLevel {
        imageConversionStatus.level
    }

    private var imageConversionStatus: (message: String, level: ConversionStatusLevel) {
        conversionStatus(
            for: .image,
            validationMessage: imageSettingsValidationMessage,
            hintMessage: imageFormatHintMessage
        )
    }
}
