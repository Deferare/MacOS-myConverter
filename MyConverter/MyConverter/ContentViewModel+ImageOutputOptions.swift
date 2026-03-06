import Foundation

extension ContentViewModel {
    var imageOutputFormatOptions: [ImageFormatOption] {
        defaultedOutputFormats(sourceURL: imageSourceURL, availableFormats: availableImageOutputFormats) {
            ContentViewModelSupport.placeholderImageFormats()
        }
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
}
