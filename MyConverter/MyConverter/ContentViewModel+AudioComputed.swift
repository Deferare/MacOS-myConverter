import Foundation

extension ContentViewModel {
    var canConvertAudio: Bool {
        canStartConversion(
            sourceURL: audioSourceURL,
            isConverting: isAudioConverting,
            isAnalyzingSource: isAnalyzingAudioSource,
            validationMessage: audioSettingsValidationMessage,
            selectedFormatAvailable: availableAudioOutputFormats.contains(where: { $0.normalizedID == selectedAudioOutputFormat.normalizedID })
        )
    }

    var selectedAudioSourceURLs: [URL] {
        guard let audioSourceURL else { return [] }
        return [audioSourceURL] + queuedAudioSourceURLs
    }

    var selectedAudioFileCount: Int {
        selectedAudioSourceURLs.count
    }

    var displayedAudioConversionProgress: Double {
        displayedProgress(isConverting: isAudioConverting, rawProgress: audioConversionProgress)
    }

    var audioProgressPercentageText: String {
        progressPercentageText(for: displayedAudioConversionProgress)
    }

    var audioConversionStatusMessage: String {
        audioConversionStatus.message
    }

    var audioConversionStatusLevel: ConversionStatusLevel {
        audioConversionStatus.level
    }

    private var audioConversionStatus: (message: String, level: ConversionStatusLevel) {
        buildConversionStatus(
            isConverting: isAudioConverting,
            currentBatchIndex: currentAudioBatchIndex,
            totalBatchCount: totalAudioBatchCount,
            isAnalyzingSource: isAnalyzingAudioSource,
            conversionErrorMessage: audioConversionErrorMessage,
            validationMessage: audioSettingsValidationMessage,
            compatibilityWarningMessage: audioSourceCompatibilityWarningMessage,
            hintMessage: audioFormatHintMessage
        )
    }
}
