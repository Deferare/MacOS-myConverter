import Foundation

extension ContentViewModel {
    func applyStoredSettings(for kind: MediaKind, sourceID: String) {
        switch kind {
        case .video:
            applyStoredVideoSettings(for: sourceID)
        case .image:
            applyStoredImageSettings(for: sourceID)
        case .audio:
            applyStoredAudioSettings(for: sourceID)
        }
    }

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
