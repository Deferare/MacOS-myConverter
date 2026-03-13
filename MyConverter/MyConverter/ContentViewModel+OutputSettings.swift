import Foundation

extension ContentViewModel {
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
            audioCodecCandidates: conditionalValues(
                when: shouldShowAudioSettings,
                selectedAudioEncoder.codecCandidates
            ),
            audioChannels: optionalValue(when: shouldShowAudioSettings, selectedAudioMode.channelCount),
            sampleRate: optionalValue(when: shouldShowAudioSampleRateOption, selectedSampleRate.hertz),
            audioBitRateKbps: optionalValue(when: shouldShowAudioBitRateOption, selectedAudioBitRate.kbps)
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
        AudioOutputSettings(
            containerFormat: selectedAudioOutputFormat,
            audioCodecCandidates: selectedAudioOutputEncoder.codecCandidates,
            audioChannels: selectedAudioOutputMode.channelCount,
            sampleRate: optionalValue(
                when: shouldShowAudioOutputSampleRateOption,
                selectedAudioOutputSampleRate.hertz
            ),
            audioBitRateKbps: optionalValue(
                when: shouldShowAudioOutputBitRateOption,
                selectedAudioOutputBitRate.kbps
            )
        )
    }
}
