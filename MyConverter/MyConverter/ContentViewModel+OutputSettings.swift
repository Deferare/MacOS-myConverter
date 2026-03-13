import Foundation

extension ContentViewModel {
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

    func resolvedAudioEncodingSettings(
        codecCandidates: [String],
        includeAudio: Bool,
        channels: Int?,
        sampleRate: Int?,
        includeSampleRate: Bool,
        bitRateKbps: Int?,
        includeBitRate: Bool
    ) -> ResolvedAudioEncodingSettings {
        ResolvedAudioEncodingSettings(
            codecCandidates: conditionalValues(when: includeAudio, codecCandidates),
            channels: optionalValue(when: includeAudio, channels),
            sampleRate: optionalValue(when: includeSampleRate, sampleRate),
            bitRateKbps: optionalValue(when: includeBitRate, bitRateKbps)
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
        let audioSettings = resolvedAudioEncodingSettings(
            codecCandidates: selectedAudioEncoder.codecCandidates,
            includeAudio: shouldShowAudioSettings,
            channels: selectedAudioMode.channelCount,
            sampleRate: selectedSampleRate.hertz,
            includeSampleRate: shouldShowAudioSampleRateOption,
            bitRateKbps: selectedAudioBitRate.kbps,
            includeBitRate: shouldShowAudioBitRateOption
        )

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
        let audioSettings = resolvedAudioEncodingSettings(
            codecCandidates: selectedAudioOutputEncoder.codecCandidates,
            includeAudio: true,
            channels: selectedAudioOutputMode.channelCount,
            sampleRate: selectedAudioOutputSampleRate.hertz,
            includeSampleRate: shouldShowAudioOutputSampleRateOption,
            bitRateKbps: selectedAudioOutputBitRate.kbps,
            includeBitRate: shouldShowAudioOutputBitRateOption
        )

        AudioOutputSettings(
            containerFormat: selectedAudioOutputFormat,
            audioCodecCandidates: audioSettings.codecCandidates,
            audioChannels: audioSettings.channels,
            sampleRate: audioSettings.sampleRate,
            audioBitRateKbps: audioSettings.bitRateKbps
        )
    }
}
