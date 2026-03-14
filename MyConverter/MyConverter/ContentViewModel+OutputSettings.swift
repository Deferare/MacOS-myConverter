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

    private struct ResolvedAudioEncodingSettings {
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
        let isEnabled = selectedOutputFormat.supportsAudioTrack
        return AudioEncodingSelectionState(
            isEnabled: isEnabled,
            selectedEncoder: selectedAudioEncoder,
            selectedMode: selectedAudioMode,
            selectedSampleRate: selectedSampleRate,
            selectedBitRate: selectedAudioBitRate,
            encoderOptions: conditionalValues(when: isEnabled, videoAudioEncoderSelectionOptions),
            shouldShowSampleRateOption: isEnabled && selectedAudioEncoder.supportsSampleRate,
            shouldShowBitRateOption: isEnabled && selectedAudioEncoder.supportsAudioBitRate
        )
    }

    var audioOutputEncodingSelectionState: AudioEncodingSelectionState {
        AudioEncodingSelectionState(
            isEnabled: true,
            selectedEncoder: selectedAudioOutputEncoder,
            selectedMode: selectedAudioOutputMode,
            selectedSampleRate: selectedAudioOutputSampleRate,
            selectedBitRate: selectedAudioOutputBitRate,
            encoderOptions: audioOutputEncoderSelectionOptions,
            shouldShowSampleRateOption: selectedAudioOutputEncoder.supportsSampleRate,
            shouldShowBitRateOption: selectedAudioOutputEncoder.supportsAudioBitRate
        )
    }

    private func resolvedAudioEncodingSettings(
        _ selection: AudioEncodingSelectionState
    ) -> ResolvedAudioEncodingSettings {
        ResolvedAudioEncodingSettings(
            codecCandidates: conditionalValues(when: selection.isEnabled, selection.selectedEncoder.codecCandidates),
            channels: optionalValue(when: selection.isEnabled, selection.selectedMode.channelCount),
            sampleRate: optionalValue(when: selection.shouldShowSampleRateOption, selection.selectedSampleRate.hertz),
            bitRateKbps: optionalValue(when: selection.shouldShowBitRateOption, selection.selectedBitRate.kbps)
        )
    }

    func resolvedVideoBitRateKbps() throws -> Int? {
        guard shouldShowVideoBitRateOption else { return nil }

        switch selectedVideoBitRate {
        case .auto:
            return nil
        case .custom:
            guard let custom = normalizedCustomVideoBitRateKbps else {
                throw ConversionError.invalidCustomVideoBitRate(customVideoBitRate)
            }
            return custom
        default:
            return selectedVideoBitRate.kbps
        }
    }

    func buildVideoOutputSettings() throws -> VideoOutputSettings {
        let audioSettings = resolvedAudioEncodingSettings(videoAudioEncodingSelectionState)

        return VideoOutputSettings(
            containerFormat: selectedOutputFormat,
            videoCodecCandidates: selectedVideoEncoder.codecCandidates,
            useHEVCTag: selectedVideoEncoder.usesHEVCCodec,
            resolution: selectedResolution.dimensions,
            frameRate: selectedFrameRate.fps,
            gifPlaybackSpeed: optionalValue(
                when: shouldShowGIFPlaybackSpeedOption,
                selectedGIFPlaybackSpeed.multiplier
            ),
            videoBitRateKbps: try resolvedVideoBitRateKbps(),
            audioCodecCandidates: audioSettings.codecCandidates,
            audioChannels: audioSettings.channels,
            sampleRate: audioSettings.sampleRate,
            audioBitRateKbps: audioSettings.bitRateKbps
        )
    }

    func buildImageOutputSettings() -> ImageOutputSettings {
        return ImageOutputSettings(
            containerFormat: selectedImageOutputFormat,
            resolution: selectedImageResolution.dimensions,
            compressionQuality: optionalValue(
                when: selectedImageOutputFormat.supportsCompressionQuality,
                selectedImageQuality.compressionQuality
            ),
            pngCompressionLevel: optionalValue(
                when: selectedImageOutputFormat.supportsPNGCompressionLevel,
                selectedPNGCompressionLevel.level
            ),
            preserveAnimation: preserveImageAnimation,
            sourceIsAnimated: imageSourceIsAnimated
        )
    }

    func buildAudioOutputSettings() -> AudioOutputSettings {
        let audioSettings = resolvedAudioEncodingSettings(audioOutputEncodingSelectionState)

        return AudioOutputSettings(
            containerFormat: selectedAudioOutputFormat,
            audioCodecCandidates: audioSettings.codecCandidates,
            audioChannels: audioSettings.channels,
            sampleRate: audioSettings.sampleRate,
            audioBitRateKbps: audioSettings.bitRateKbps
        )
    }
}
