import Foundation

extension ContentViewModel {
    func persistCurrentAudioSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(using: audioSettingsDescriptor()) {
            AudioConversionSettings(
                outputFormatID: selectedAudioOutputFormat.id,
                audioEncoder: selectedAudioOutputEncoder,
                audioMode: selectedAudioOutputMode,
                sampleRate: selectedAudioOutputSampleRate,
                audioBitRate: selectedAudioOutputBitRate
            )
        }
    }
}
