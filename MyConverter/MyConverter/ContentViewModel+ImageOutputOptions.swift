import Foundation

extension ContentViewModel {
    var imageSourceIsAnimated: Bool {
        imageRuntimeState.sourceFrameCount > 1
    }

    var imageOutputFormatOptions: [ImageFormatOption] {
        Self.imageOutputFormatDescriptorValue.availableOptions(in: self)
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
