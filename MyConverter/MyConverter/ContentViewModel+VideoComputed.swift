import Foundation

extension ContentViewModel {
    // MARK: - Video Computed Properties

    var canConvert: Bool {
        sourceURL != nil &&
            !isConverting &&
            !isAnalyzingSource &&
            videoSettingsValidationMessage == nil
    }

    var selectedVideoSourceURLs: [URL] {
        guard let sourceURL else { return [] }
        return [sourceURL] + queuedSourceURLs
    }

    var selectedVideoFileCount: Int {
        selectedVideoSourceURLs.count
    }

    var displayedConversionProgress: Double {
        let rawProgress = isConverting ? conversionProgress : 0
        return rawProgress < 0.01 ? 0 : rawProgress
    }

    var progressPercentageText: String {
        let percent = Int((displayedConversionProgress * 100).rounded())
        return "\(max(0, min(percent, 100)))%"
    }

    var conversionStatusMessage: String {
        conversionStatus.message
    }

    var conversionStatusLevel: ConversionStatusLevel {
        conversionStatus.level
    }

    var isVideoSettingsValid: Bool {
        if shouldShowVideoBitRateOption && selectedVideoBitRate == .custom {
            return normalizedCustomVideoBitRateKbps != nil
        }
        return true
    }

    var videoSettingsValidationMessage: String? {
        if let sourceCompatibilityErrorMessage {
            return sourceCompatibilityErrorMessage
        }
        if sourceURL != nil && requiresFFmpegForCurrentVideoSettings && !VideoConversionEngine.isFFmpegAvailable() {
            return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
        }
        if shouldShowVideoBitRateOption && selectedVideoBitRate == .custom && normalizedCustomVideoBitRateKbps == nil {
            return "Please enter an integer greater than 1 for Custom Bitrate (Kbps)."
        }
        if sourceURL != nil && !availableOutputFormats.contains(where: { $0.normalizedID == selectedOutputFormat.normalizedID }) {
            return "Selected container is not available for this source."
        }
        if !videoEncoderOptions.contains(selectedVideoEncoder) {
            return "Selected video encoder is not available for this format."
        }
        if shouldShowAudioSettings && !audioEncoderOptions.contains(selectedAudioEncoder) {
            return "Selected audio encoder is not available for this format."
        }
        return nil
    }

    var outputFormatOptions: [VideoFormatOption] {
        if sourceURL == nil && availableOutputFormats.isEmpty {
            return VideoConversionEngine.defaultOutputFormats()
        }
        return availableOutputFormats
    }

    var videoEncoderOptions: [VideoEncoderOption] {
        if !availableVideoEncoders.isEmpty {
            return availableVideoEncoders
        }
        return selectedOutputFormat.avFileType == nil ? [] : [.auto]
    }

    var audioEncoderOptions: [AudioEncoderOption] {
        if !shouldShowAudioSettings {
            return []
        }
        if !availableAudioEncoders.isEmpty {
            return availableAudioEncoders
        }
        return selectedOutputFormat.avFileType == nil ? [] : [.auto]
    }

    var shouldShowVideoEncoderOption: Bool {
        selectedOutputFormat.supportsVideoEncoderSelection && videoEncoderOptions.count > 1
    }

    var shouldShowAudioSettings: Bool {
        selectedOutputFormat.supportsAudioTrack
    }

    var shouldShowVideoBitRateOption: Bool {
        selectedVideoEncoder.supportsVideoBitRate
    }

    var shouldShowGIFPlaybackSpeedOption: Bool {
        selectedOutputFormat.usesGIFPalettePipeline
    }

    var shouldShowAudioSampleRateOption: Bool {
        shouldShowAudioSettings && selectedAudioEncoder.supportsSampleRate
    }

    var shouldShowAudioBitRateOption: Bool {
        shouldShowAudioSettings && selectedAudioEncoder.supportsAudioBitRate
    }

    var normalizedCustomVideoBitRateKbps: Int? {
        let trimmed = customVideoBitRate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Int(sanitized), value > 0 else { return nil }
        return value
    }

    var requiresFFmpegForCurrentVideoSettings: Bool {
        if selectedOutputFormat.avFileType == nil {
            return true
        }
        if selectedOutputFormat.usesGIFPalettePipeline {
            return true
        }
        if selectedVideoEncoder != .auto {
            return true
        }
        if selectedResolution != .original || selectedFrameRate != .original {
            return true
        }
        if shouldShowVideoBitRateOption && selectedVideoBitRate != .auto {
            return true
        }
        if !shouldShowAudioSettings {
            return false
        }
        if selectedAudioEncoder != .auto {
            return true
        }
        if selectedAudioMode != .auto {
            return true
        }
        if shouldShowAudioBitRateOption && selectedAudioBitRate != .auto {
            return true
        }
        return false
    }

    private var conversionStatus: (message: String, level: ConversionStatusLevel) {
        buildConversionStatus(
            isConverting: isConverting,
            currentBatchIndex: currentVideoBatchIndex,
            totalBatchCount: totalVideoBatchCount,
            isAnalyzingSource: isAnalyzingSource,
            conversionErrorMessage: conversionErrorMessage,
            validationMessage: videoSettingsValidationMessage,
            compatibilityWarningMessage: sourceCompatibilityWarningMessage
        )
    }
}
