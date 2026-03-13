import Foundation

extension ContentViewModel {
    var outputFormatOptions: [VideoFormatOption] {
        availableOutputFormatOptions(using: videoOutputFormatDescriptor())
    }

    var videoEncoderOptions: [VideoEncoderOption] {
        resolvedOptions(
            availableVideoEncoders,
            autoOption: VideoEncoderOption.auto,
            includesAutoOption: selectedOutputFormat.avFileType != nil
        )
    }

    var audioEncoderOptions: [AudioEncoderOption] {
        if !shouldShowAudioSettings {
            return []
        }
        return resolvedOptions(
            availableAudioEncoders,
            autoOption: AudioEncoderOption.auto,
            includesAutoOption: selectedOutputFormat.avFileType != nil
        )
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
}
