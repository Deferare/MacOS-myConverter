import Foundation

extension ContentViewModel {
    var audioFormatHintMessage: String? {
        if let warning = audioSourceCompatibilityWarningMessage, !warning.isEmpty {
            return warning
        }
        return nil
    }

    var audioSettingsValidationMessage: String? {
        if let audioSourceCompatibilityErrorMessage {
            return audioSourceCompatibilityErrorMessage
        }
        if audioSourceURL != nil && !isSelectedOutputFormatAvailable(using: audioOutputFormatDescriptor()) {
            return "Selected output format is not available for this source."
        }
        if !audioOutputEncoderOptions.contains(selectedAudioOutputEncoder) {
            return "Selected audio encoder is not available for this format."
        }
        return nil
    }
}
