import Foundation

extension ContentViewModel {
    var outputFormatOptions: [VideoFormatOption] {
        availableOutputFormatOptions(using: Self.videoOutputFormatDescriptorValue)
    }

    var videoEncoderOptions: [VideoEncoderOption] {
        resolvedOptions(
            videoRuntimeState.availableVideoEncoders,
            autoOption: VideoEncoderOption.auto,
            includesAutoOption: videoOptionsState.selectedOutputFormat.avFileType != nil
        )
    }

    var audioEncoderOptions: [AudioEncoderOption] {
        videoAudioEncoderSelectionOptions
    }

    var shouldShowVideoEncoderOption: Bool {
        videoOptionsState.selectedOutputFormat.supportsVideoEncoderSelection && videoEncoderOptions.count > 1
    }

    var shouldShowAudioSettings: Bool {
        videoAudioEncodingSelectionState.isEnabled
    }

    var shouldShowVideoBitRateOption: Bool {
        videoOptionsState.selectedVideoEncoder.supportsVideoBitRate
    }

    var shouldShowGIFPlaybackSpeedOption: Bool {
        videoOptionsState.selectedOutputFormat.usesGIFPalettePipeline
    }

    var shouldShowAudioSampleRateOption: Bool {
        videoAudioEncodingSelectionState.shouldShowSampleRateOption
    }

    var shouldShowAudioBitRateOption: Bool {
        videoAudioEncodingSelectionState.shouldShowBitRateOption
    }

    var normalizedCustomVideoBitRateKbps: Int? {
        let trimmed = videoOptionsState.customVideoBitRate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Int(sanitized), value > 0 else { return nil }
        return value
    }

    var requiresFFmpegForCurrentVideoSettings: Bool {
        let audioSettings = videoAudioEncodingSelectionState
        if videoOptionsState.selectedOutputFormat.avFileType == nil {
            return true
        }
        if videoOptionsState.selectedOutputFormat.usesGIFPalettePipeline {
            return true
        }
        if videoOptionsState.selectedVideoEncoder != .auto {
            return true
        }
        if videoOptionsState.selectedResolution != .original || videoOptionsState.selectedFrameRate != .original {
            return true
        }
        if shouldShowVideoBitRateOption && videoOptionsState.selectedVideoBitRate != .auto {
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
