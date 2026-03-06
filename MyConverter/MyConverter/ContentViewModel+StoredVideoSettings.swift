import Foundation

extension ContentViewModel {
    func applyStoredSettings(_ settings: VideoConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
            formatDescriptor: videoOutputFormatDescriptor(),
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
        ensureSelectedOutputFormatIsAvailable(using: videoOutputFormatDescriptor())
    }
}
