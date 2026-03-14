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

        switch videoOptionsState.selectedVideoBitRate {
        case .auto:
            return nil
        case .custom:
            guard let custom = normalizedCustomVideoBitRateKbps else {
                throw ConversionError.invalidCustomVideoBitRate(videoOptionsState.customVideoBitRate)
            }
            return custom
        default:
            return videoOptionsState.selectedVideoBitRate.kbps
        }
    }

    func buildVideoOutputSettings() throws -> VideoOutputSettings {
        let options = videoOptionsState
        let audioSettings = resolvedAudioEncodingSettings(videoAudioEncodingSelectionState)

        return VideoOutputSettings(
            containerFormat: options.selectedOutputFormat,
            videoCodecCandidates: options.selectedVideoEncoder.codecCandidates,
            useHEVCTag: options.selectedVideoEncoder.usesHEVCCodec,
            resolution: options.selectedResolution.dimensions,
            frameRate: options.selectedFrameRate.fps,
            gifPlaybackSpeed: optionalValue(
                when: shouldShowGIFPlaybackSpeedOption,
                options.selectedGIFPlaybackSpeed.multiplier
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
            containerFormat: imageOptionsState.selectedOutputFormat,
            resolution: imageOptionsState.selectedResolution.dimensions,
            compressionQuality: optionalValue(
                when: imageOptionsState.selectedOutputFormat.supportsCompressionQuality,
                imageOptionsState.selectedQuality.compressionQuality
            ),
            pngCompressionLevel: optionalValue(
                when: imageOptionsState.selectedOutputFormat.supportsPNGCompressionLevel,
                imageOptionsState.selectedPNGCompressionLevel.level
            ),
            preserveAnimation: imageOptionsState.preserveAnimation,
            sourceIsAnimated: imageSourceIsAnimated
        )
    }

    func buildAudioOutputSettings() -> AudioOutputSettings {
        let audioSettings = resolvedAudioEncodingSettings(audioOutputEncodingSelectionState)

        return AudioOutputSettings(
            containerFormat: audioOptionsState.selectedOutputFormat,
            audioCodecCandidates: audioSettings.codecCandidates,
            audioChannels: audioSettings.channels,
            sampleRate: audioSettings.sampleRate,
            audioBitRateKbps: audioSettings.bitRateKbps
        )
    }
}
