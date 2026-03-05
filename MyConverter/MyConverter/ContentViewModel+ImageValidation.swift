import Foundation

extension ContentViewModel {
    var isImageSettingsValid: Bool {
        imageSettingsValidationMessage == nil
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
}
