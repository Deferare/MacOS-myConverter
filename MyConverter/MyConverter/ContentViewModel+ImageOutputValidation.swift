import Foundation

extension ContentViewModel {
    func validateImageOutputSettings(for sourceURL: URL) async -> String? {
        await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedImageOutputFormat.normalizedID,
            unavailableMessage: "Selected output format is not available for this source.",
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            additionalValidation: { capabilities in
                if capabilities.frameCount > 1 &&
                    preserveImageAnimation &&
                    selectedImageOutputFormat.supportsAnimation &&
                    !ImageConversionEngine.isFFmpegAvailable() {
                    return "Animated output requires ffmpeg for the selected format."
                }
                return nil
            }
        )
    }
}
