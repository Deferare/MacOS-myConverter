import Foundation

extension ContentViewModel {
    var imageSourceIsAnimated: Bool {
        imageRuntimeState.sourceFrameCount > 1
    }

    var imageOutputFormatOptions: [ImageFormatOption] {
        availableOutputFormatOptions(using: Self.imageOutputFormatDescriptorValue)
    }

    var shouldShowImageQualityOption: Bool {
        imageOptionsState.selectedOutputFormat.supportsCompressionQuality
    }

    var shouldShowPNGCompressionOption: Bool {
        imageOptionsState.selectedOutputFormat.supportsPNGCompressionLevel
    }

    var shouldShowPreserveAnimationOption: Bool {
        imageSourceIsAnimated && imageOptionsState.selectedOutputFormat.supportsAnimation
    }
}
