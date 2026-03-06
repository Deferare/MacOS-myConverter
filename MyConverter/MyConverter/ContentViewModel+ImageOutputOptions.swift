import Foundation

extension ContentViewModel {
    var imageOutputFormatOptions: [ImageFormatOption] {
        availableOutputFormatOptions(using: imageOutputFormatDescriptor())
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
