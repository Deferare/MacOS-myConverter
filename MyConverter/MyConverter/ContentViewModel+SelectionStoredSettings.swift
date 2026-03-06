import Foundation

extension ContentViewModel {
    func applyStoredVideoSettings(for sourceID: String) {
        applyStoredSettingsForSource(sourceID: sourceID, using: videoSettingsDescriptor(), defaultSettings: VideoConversionSettings()) {
            applyStoredSettings($0)
        }
    }

    func applyStoredImageSettings(for sourceID: String) {
        applyStoredSettingsForSource(sourceID: sourceID, using: imageSettingsDescriptor(), defaultSettings: ImageConversionSettings()) {
            applyStoredImageSettings($0)
        }
    }

    func applyStoredAudioSettings(for sourceID: String) {
        applyStoredSettingsForSource(sourceID: sourceID, using: audioSettingsDescriptor(), defaultSettings: AudioConversionSettings()) {
            applyStoredAudioSettings($0)
        }
    }
}
