import Foundation

extension ContentViewModel {
    var audioFormatHintMessage: String? {
        compatibilityHintMessage(for: .audio)
    }

    var audioSettingsValidationMessage: String? {
        outputSettingsValidationMessage(
            for: .audio,
            formatDescriptor: audioOutputFormatDescriptor(),
            unavailableMessage: "Selected output format is not available for this source."
        ) {
            if !audioOutputEncoderOptions.contains(selectedAudioOutputEncoder) {
                return "Selected audio encoder is not available for this format."
            }
            return nil
        }
    }
}
