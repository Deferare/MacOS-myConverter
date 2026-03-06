import Foundation

extension ContentViewModel {
    var imageFormatHintMessage: String? {
        firstNonEmptyMessage(
            imageSourceIsAnimated && !selectedImageOutputFormat.supportsAnimation
                ? "This format exports only the first frame for animated sources."
                : nil,
            shouldShowPreserveAnimationOption && !ImageConversionEngine.isFFmpegAvailable()
                ? "ffmpeg is required to preserve animation."
                : nil
        )
    }

    var imageSettingsValidationMessage: String? {
        outputSettingsValidationMessage(
            for: .image,
            formatDescriptor: imageOutputFormatDescriptor(),
            unavailableMessage: "Selected output format is not available for this source."
        ) {
            if imageSourceIsAnimated &&
                preserveImageAnimation &&
                selectedImageOutputFormat.supportsAnimation &&
                !ImageConversionEngine.isFFmpegAvailable() {
                return "Animated output requires ffmpeg for the selected format."
            }
            return nil
        }
    }
}
