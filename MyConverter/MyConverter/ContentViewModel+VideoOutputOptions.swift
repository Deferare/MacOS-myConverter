import Foundation

extension ContentViewModel {
    var outputFormatOptions: [VideoFormatOption] {
        availableOutputFormatOptions(using: Self.videoOutputFormatDescriptorValue)
    }

    var videoEncoderOptions: [VideoEncoderOption] {
        resolvedOptions(
            videoRuntimeState.availableVideoEncoders,
            autoOption: VideoEncoderOption.auto,
            includesAutoOption: selectedOutputFormat.avFileType != nil
        )
    }

    var audioEncoderOptions: [AudioEncoderOption] {
        videoAudioEncoderSelectionOptions
    }

    var shouldShowVideoEncoderOption: Bool {
        selectedOutputFormat.supportsVideoEncoderSelection && videoEncoderOptions.count > 1
    }

    var shouldShowAudioSettings: Bool {
        videoAudioEncodingSelectionState.isEnabled
    }

    var shouldShowVideoBitRateOption: Bool {
        selectedVideoEncoder.supportsVideoBitRate
    }

    var shouldShowGIFPlaybackSpeedOption: Bool {
        selectedOutputFormat.usesGIFPalettePipeline
    }

    var shouldShowAudioSampleRateOption: Bool {
        videoAudioEncodingSelectionState.shouldShowSampleRateOption
    }

    var shouldShowAudioBitRateOption: Bool {
        videoAudioEncodingSelectionState.shouldShowBitRateOption
    }

    var normalizedCustomVideoBitRateKbps: Int? {
        let trimmed = customVideoBitRate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Int(sanitized), value > 0 else { return nil }
        return value
    }

    var requiresFFmpegForCurrentVideoSettings: Bool {
        let audioSettings = videoAudioEncodingSelectionState
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
        if !audioSettings.isEnabled {
            return false
        }
        if audioSettings.selectedEncoder != .auto {
            return true
        }
        if audioSettings.selectedMode != .auto {
            return true
        }
        if audioSettings.shouldShowBitRateOption && audioSettings.selectedBitRate != .auto {
            return true
        }
        return false
    }
}
