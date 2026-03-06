import Foundation

extension ContentViewModel {
    func persistCurrentSettingsIfNeeded() {
        persistCurrentVideoSettingsIfNeeded()
    }

    func persistCurrentVideoSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(using: videoSettingsDescriptor()) {
            VideoConversionSettings(
                outputFormatID: selectedOutputFormat.id,
                videoEncoder: selectedVideoEncoder,
                resolution: selectedResolution,
                frameRate: selectedFrameRate,
                gifPlaybackSpeed: selectedGIFPlaybackSpeed,
                videoBitRate: selectedVideoBitRate,
                customVideoBitRate: customVideoBitRate,
                audioEncoder: selectedAudioEncoder,
                audioMode: selectedAudioMode,
                sampleRate: selectedSampleRate,
                audioBitRate: selectedAudioBitRate
            )
        }
    }

    func savePersistedSettings() {
        schedulePersistedSourceSettingsSave(using: videoSettingsDescriptor())
    }

    func loadPersistedSettings() -> [String: VideoConversionSettings] {
        loadPersistedSourceSettings(using: videoSettingsDescriptor())
    }
}
