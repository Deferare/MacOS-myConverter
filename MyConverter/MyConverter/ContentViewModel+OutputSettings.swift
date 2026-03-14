import Foundation

extension ContentViewModel {
    func resolvedVideoBitRateKbps() throws -> Int? {
        let selection = videoEncodingSelectionState
        guard selection.shouldShowVideoBitRateOption else { return nil }

        switch selection.selectedVideoBitRate {
        case .auto:
            return nil
        case .custom:
            guard let custom = selection.normalizedCustomVideoBitRateKbps else {
                throw ConversionError.invalidCustomVideoBitRate(selection.customVideoBitRate)
            }
            return custom
        default:
            return selection.selectedVideoBitRate.kbps
        }
    }

    func buildVideoOutputSettings() throws -> VideoOutputSettings {
        let selection = videoEncodingSelectionState
        let audioSettings = resolvedAudioEncodingSettings(selection.audioSettings)

        return VideoOutputSettings(
            containerFormat: selection.selectedOutputFormat,
            videoCodecCandidates: selection.selectedVideoEncoder.codecCandidates,
            useHEVCTag: selection.selectedVideoEncoder.usesHEVCCodec,
            resolution: selection.selectedResolution.dimensions,
            frameRate: selection.selectedFrameRate.fps,
            gifPlaybackSpeed: optionalValue(
                when: selection.shouldShowGIFPlaybackSpeedOption,
                selection.selectedGIFPlaybackSpeed.multiplier
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
