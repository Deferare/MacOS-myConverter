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

    func savePersistedAudioSettings() {
        schedulePersistedSourceSettingsSave(using: audioSettingsDescriptor())
    }

    func loadPersistedAudioSettings() -> [String: AudioConversionSettings] {
        loadPersistedSourceSettings(using: audioSettingsDescriptor())
    }
}
