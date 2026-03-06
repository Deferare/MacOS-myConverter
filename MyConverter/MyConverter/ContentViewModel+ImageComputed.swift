import Foundation

extension ContentViewModel {
    var imageSourceIsAnimated: Bool {
        imageSourceFrameCount > 1
    }

    var canConvertImage: Bool {
        canStartConversion(for: .image, validationMessage: imageSettingsValidationMessage)
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
        statusMessage(
            for: .image,
            validationMessage: imageSettingsValidationMessage,
            hintMessage: imageFormatHintMessage
        )
    }

    var imageConversionStatusLevel: ConversionStatusLevel {
        statusLevel(
            for: .image,
            validationMessage: imageSettingsValidationMessage,
            hintMessage: imageFormatHintMessage
        )
    }
}
