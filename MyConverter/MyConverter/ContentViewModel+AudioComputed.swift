import Foundation

extension ContentViewModel {
    // MARK: - Audio Computed Properties

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

    var audioOutputFormatOptions: [AudioFormatOption] {
        defaultedOutputFormats(sourceURL: audioSourceURL, availableFormats: availableAudioOutputFormats) {
            VideoConversionEngine.defaultAudioOutputFormats()
        }
    }

    var audioOutputEncoderOptions: [AudioEncoderOption] {
        if !availableAudioOutputEncoders.isEmpty {
            return availableAudioOutputEncoders
        }
        if audioSourceURL == nil && selectedAudioOutputFormat.allowsFFmpegAutomaticAudioCodec {
            return [.auto]
        }
        return []
    }

    var shouldShowAudioOutputSampleRateOption: Bool {
        selectedAudioOutputEncoder.supportsSampleRate
    }

    var shouldShowAudioOutputBitRateOption: Bool {
        selectedAudioOutputEncoder.supportsAudioBitRate
    }

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
        if audioSourceURL != nil &&
            !availableAudioOutputFormats.contains(where: { $0.normalizedID == selectedAudioOutputFormat.normalizedID }) {
            return "Selected output format is not available for this source."
        }
        if !audioOutputEncoderOptions.contains(selectedAudioOutputEncoder) {
            return "Selected audio encoder is not available for this format."
        }
        return nil
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
