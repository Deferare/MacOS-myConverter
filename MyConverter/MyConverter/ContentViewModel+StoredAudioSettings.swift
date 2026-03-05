import Foundation

extension ContentViewModel {
    func applyStoredAudioSettings(_ settings: AudioConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredAudioSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            options: audioOutputFormatOptions,
            selectedFormatKeyPath: \.selectedAudioOutputFormat,
            formatNormalizedID: { $0.normalizedID },
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
        ensureSelectedFormatIsAvailable(
            options: audioOutputFormatOptions,
            selectedFormatKeyPath: \.selectedAudioOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: AudioFormatOption.defaultSelection(from:)
        )
    }
}
