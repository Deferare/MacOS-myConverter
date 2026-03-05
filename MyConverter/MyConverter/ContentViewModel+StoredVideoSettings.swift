import Foundation

extension ContentViewModel {
    func applyStoredSettings(_ settings: VideoConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
            options: outputFormatOptions,
            selectedFormatKeyPath: \.selectedOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedVideoEncoder = settings.videoEncoder
                selectedResolution = settings.resolution
                selectedFrameRate = settings.frameRate
                selectedGIFPlaybackSpeed = settings.gifPlaybackSpeed
                selectedVideoBitRate = settings.videoBitRate
                customVideoBitRate = settings.customVideoBitRate
                selectedAudioEncoder = settings.audioEncoder
                selectedAudioMode = settings.audioMode
                selectedSampleRate = settings.sampleRate
                selectedAudioBitRate = settings.audioBitRate
            },
            postApply: {
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    func ensureSelectedVideoOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: outputFormatOptions,
            selectedFormatKeyPath: \.selectedOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: VideoFormatOption.defaultSelection(from:)
        )
    }
}
