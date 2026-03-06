import Foundation

extension ContentViewModel {
    func validateVideoOutputSettings(for sourceURL: URL) async -> String? {
        if requiresFFmpegForCurrentVideoSettings && !VideoConversionEngine.isFFmpegAvailable() {
            return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
        }

        return await validateSelectedOutputFormatAvailability(
            for: sourceURL,
            formatDescriptor: videoOutputFormatDescriptor(),
            unavailableMessage: "Selected container is not available for this source.",
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage }
        )
    }
}
