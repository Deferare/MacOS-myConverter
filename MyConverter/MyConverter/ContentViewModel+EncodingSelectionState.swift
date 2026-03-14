import Foundation

extension ContentViewModel {
    struct AudioEncodingSelectionState: Equatable {
        let isEnabled: Bool
        let selectedEncoder: AudioEncoderOption
        let selectedMode: AudioModeOption
        let selectedSampleRate: SampleRateOption
        let selectedBitRate: AudioBitRateOption
        let encoderOptions: [AudioEncoderOption]
        let shouldShowSampleRateOption: Bool
        let shouldShowBitRateOption: Bool
    }

    struct VideoEncodingSelectionState: Equatable {
        let selectedOutputFormat: VideoFormatOption
        let selectedVideoEncoder: VideoEncoderOption
        let selectedResolution: ResolutionOption
        let selectedFrameRate: FrameRateOption
        let selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption
        let selectedVideoBitRate: VideoBitRateOption
        let customVideoBitRate: String
        let audioSettings: AudioEncodingSelectionState
        let outputFormatOptions: [VideoFormatOption]
        let videoEncoderOptions: [VideoEncoderOption]
        let shouldShowVideoEncoderOption: Bool
        let shouldShowGIFPlaybackSpeedOption: Bool
        let shouldShowVideoBitRateOption: Bool

        var shouldShowAudioSettings: Bool {
            audioSettings.isEnabled
        }

        var normalizedCustomVideoBitRateKbps: Int? {
            let trimmed = customVideoBitRate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
            guard let value = Int(sanitized), value > 0 else { return nil }
            return value
        }

        var requiresFFmpeg: Bool {
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

    struct ResolvedAudioEncodingSettings {
        let codecCandidates: [String]
        let channels: Int?
        let sampleRate: Int?
        let bitRateKbps: Int?
    }

    func resolvedOptions<Option>(
        _ options: [Option],
        fallback: () -> [Option]
    ) -> [Option] {
        if !options.isEmpty {
            return options
        }
        return fallback()
    }

    func resolvedOptions<Option>(
        _ options: [Option],
        autoOption: Option,
        includesAutoOption: Bool
    ) -> [Option] {
        resolvedOptions(options) {
            includesAutoOption ? [autoOption] : []
        }
    }

    func optionalValue<Value>(
        when condition: Bool,
        _ value: @autoclosure () -> Value?
    ) -> Value? {
        condition ? value() : nil
    }

    func conditionalValues<Value>(
        when condition: Bool,
        _ values: @autoclosure () -> [Value]
    ) -> [Value] {
        condition ? values() : []
    }

    var videoAudioEncodingSelectionState: AudioEncodingSelectionState {
        let options = videoOptionsState
        let isEnabled = options.selectedOutputFormat.supportsAudioTrack
        return AudioEncodingSelectionState(
            isEnabled: isEnabled,
            selectedEncoder: options.selectedAudioEncoder,
            selectedMode: options.selectedAudioMode,
            selectedSampleRate: options.selectedSampleRate,
            selectedBitRate: options.selectedAudioBitRate,
            encoderOptions: conditionalValues(when: isEnabled, videoAudioEncoderSelectionOptions),
            shouldShowSampleRateOption: isEnabled && options.selectedAudioEncoder.supportsSampleRate,
            shouldShowBitRateOption: isEnabled && options.selectedAudioEncoder.supportsAudioBitRate
        )
    }

    var audioOutputEncodingSelectionState: AudioEncodingSelectionState {
        AudioEncodingSelectionState(
            isEnabled: true,
            selectedEncoder: audioOptionsState.selectedOutputEncoder,
            selectedMode: audioOptionsState.selectedOutputMode,
            selectedSampleRate: audioOptionsState.selectedOutputSampleRate,
            selectedBitRate: audioOptionsState.selectedOutputBitRate,
            encoderOptions: audioOutputEncoderSelectionOptions,
            shouldShowSampleRateOption: audioOptionsState.selectedOutputEncoder.supportsSampleRate,
            shouldShowBitRateOption: audioOptionsState.selectedOutputEncoder.supportsAudioBitRate
        )
    }

    var videoEncodingSelectionState: VideoEncodingSelectionState {
        let options = videoOptionsState
        let audioSettings = videoAudioEncodingSelectionState
        let outputFormatOptions = availableOutputFormatOptions(
            using: Self.videoOutputFormatDescriptor
        )
        let videoEncoderOptions = resolvedOptions(
            videoRuntimeState.availableVideoEncoders,
            autoOption: VideoEncoderOption.auto,
            includesAutoOption: options.selectedOutputFormat.avFileType != nil
        )

        return VideoEncodingSelectionState(
            selectedOutputFormat: options.selectedOutputFormat,
            selectedVideoEncoder: options.selectedVideoEncoder,
            selectedResolution: options.selectedResolution,
            selectedFrameRate: options.selectedFrameRate,
            selectedGIFPlaybackSpeed: options.selectedGIFPlaybackSpeed,
            selectedVideoBitRate: options.selectedVideoBitRate,
            customVideoBitRate: options.customVideoBitRate,
            audioSettings: audioSettings,
            outputFormatOptions: outputFormatOptions,
            videoEncoderOptions: videoEncoderOptions,
            shouldShowVideoEncoderOption: options.selectedOutputFormat.supportsVideoEncoderSelection
                && videoEncoderOptions.count > 1,
            shouldShowGIFPlaybackSpeedOption: options.selectedOutputFormat.usesGIFPalettePipeline,
            shouldShowVideoBitRateOption: options.selectedVideoEncoder.supportsVideoBitRate
        )
    }

    func resolvedAudioEncodingSettings(
        _ selection: AudioEncodingSelectionState
    ) -> ResolvedAudioEncodingSettings {
        ResolvedAudioEncodingSettings(
            codecCandidates: conditionalValues(when: selection.isEnabled, selection.selectedEncoder.codecCandidates),
            channels: optionalValue(when: selection.isEnabled, selection.selectedMode.channelCount),
            sampleRate: optionalValue(when: selection.shouldShowSampleRateOption, selection.selectedSampleRate.hertz),
            bitRateKbps: optionalValue(when: selection.shouldShowBitRateOption, selection.selectedBitRate.kbps)
        )
    }
}
