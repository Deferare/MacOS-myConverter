import Foundation

extension ContentViewModel {
    func applyStoredAudioSettings(_ settings: AudioConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.settingsState.isApplyingAudioSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            formatDescriptor: audioOutputFormatDescriptor(),
            applyAdditionalSettings: {
                selectedAudioOutputEncoder = settings.audioEncoder
                selectedAudioOutputMode = settings.audioMode
                selectedAudioOutputSampleRate = settings.sampleRate
                selectedAudioOutputBitRate = settings.audioBitRate
            },
            postApply: {
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }

    func ensureSelectedAudioOutputFormatIsAvailable() {
        ensureSelectedOutputFormatIsAvailable(using: audioOutputFormatDescriptor())
    }
}
