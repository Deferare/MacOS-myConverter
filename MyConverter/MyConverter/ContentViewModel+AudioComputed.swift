import Foundation

extension ContentViewModel {
    var canConvertAudio: Bool {
        canStartConversion(for: .audio, validationMessage: audioSettingsValidationMessage)
    }

    var selectedAudioSourceURLs: [URL] {
        selectedSourceURLs(for: .audio)
    }

    var selectedAudioFileCount: Int {
        selectedFileCount(for: .audio)
    }

    var displayedAudioConversionProgress: Double {
        displayedProgress(for: .audio)
    }

    var audioProgressPercentageText: String {
        progressPercentageText(for: .audio)
    }

    var audioConversionStatusMessage: String {
        statusMessage(
            for: .audio,
            validationMessage: audioSettingsValidationMessage,
            hintMessage: audioFormatHintMessage
        )
    }

    var audioConversionStatusLevel: ConversionStatusLevel {
        statusLevel(
            for: .audio,
            validationMessage: audioSettingsValidationMessage,
            hintMessage: audioFormatHintMessage
        )
    }
}
