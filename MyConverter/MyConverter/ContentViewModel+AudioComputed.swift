import Foundation

extension ContentViewModel {
    var canConvertAudio: Bool {
        canStartConversion(
            for: .audio,
            validationMessage: audioSettingsValidationMessage,
            selectedFormatAvailable: availableAudioOutputFormats.contains(where: { $0.normalizedID == selectedAudioOutputFormat.normalizedID })
        )
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
        audioConversionStatus.message
    }

    var audioConversionStatusLevel: ConversionStatusLevel {
        audioConversionStatus.level
    }

    private var audioConversionStatus: (message: String, level: ConversionStatusLevel) {
        conversionStatus(
            for: .audio,
            validationMessage: audioSettingsValidationMessage,
            hintMessage: audioFormatHintMessage
        )
    }
}
