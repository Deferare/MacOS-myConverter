import Foundation

extension ContentViewModel {
    func validateAudioOutputSettings(for sourceURL: URL) async -> String? {
        await validateSelectedOutputFormatAvailability(
            for: sourceURL,
            formatDescriptor: audioOutputFormatDescriptor(),
            unavailableMessage: "Selected output format is not available for this source.",
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage }
        )
    }
}
