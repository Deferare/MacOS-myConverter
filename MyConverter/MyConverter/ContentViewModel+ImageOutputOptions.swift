import Foundation

extension ContentViewModel {
    var imageSourceIsAnimated: Bool {
        imageSourceFrameCount > 1
    }

    var imageOutputFormatOptions: [ImageFormatOption] {
        availableOutputFormatOptions(using: Self.imageOutputFormatDescriptorValue)
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
