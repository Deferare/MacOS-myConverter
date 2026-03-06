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
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: videoSettingsBySourceID,
            defaultSettings: VideoConversionSettings(),
            apply: { settings in
                applyStoredSettings(settings)
            }
        )
    }

    func applyStoredImageSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: imageSettingsBySourceID,
            defaultSettings: ImageConversionSettings(),
            apply: { settings in
                applyStoredImageSettings(settings)
            }
        )
    }

    func applyStoredAudioSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: audioSettingsBySourceID,
            defaultSettings: AudioConversionSettings(),
            apply: { settings in
                applyStoredAudioSettings(settings)
            }
        )
    }
}
