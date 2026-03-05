import Foundation

extension ContentViewModel {
    // MARK: - Audio Computed Properties

    var canConvertAudio: Bool {
        audioSourceURL != nil &&
            !isAudioConverting &&
            !isAnalyzingAudioSource &&
            audioSettingsValidationMessage == nil &&
            availableAudioOutputFormats.contains(where: { $0.normalizedID == selectedAudioOutputFormat.normalizedID })
    }

    var selectedAudioSourceURLs: [URL] {
        guard let audioSourceURL else { return [] }
        return [audioSourceURL] + queuedAudioSourceURLs
    }

    var selectedAudioFileCount: Int {
        selectedAudioSourceURLs.count
    }

    var displayedAudioConversionProgress: Double {
        let rawProgress = isAudioConverting ? audioConversionProgress : 0
        return rawProgress < 0.01 ? 0 : rawProgress
    }

    var audioProgressPercentageText: String {
        let percent = Int((displayedAudioConversionProgress * 100).rounded())
        return "\(max(0, min(percent, 100)))%"
    }

    var audioConversionStatusMessage: String {
        audioConversionStatus.message
    }

    var audioConversionStatusLevel: ConversionStatusLevel {
        audioConversionStatus.level
    }

    var audioOutputFormatOptions: [AudioFormatOption] {
        if availableAudioOutputFormats.isEmpty && audioSourceURL == nil {
            return VideoConversionEngine.defaultAudioOutputFormats()
        }
        return availableAudioOutputFormats
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
