import Foundation

extension ContentViewModel.MediaKind {
    private struct SourceSettingsBehavior {
        let applyDefaultSourceSettings: (ContentViewModel) -> Void
        let applyStoredSourceSettings: (ContentViewModel, String) -> Void
        let persistCurrentSourceSettingsIfNeeded: (ContentViewModel) -> Void
    }

    private static let sourceSettingsBehaviorByKind: [Self: SourceSettingsBehavior] = [
        .video: SourceSettingsBehavior(
            applyDefaultSourceSettings: {
                $0.applyVideoSourceSettings(VideoConversionSettings())
            },
            applyStoredSourceSettings: { viewModel, sourceID in
                viewModel.applyStoredVideoSourceSettings(for: sourceID)
            },
            persistCurrentSourceSettingsIfNeeded: {
                $0.persistCurrentVideoSourceSettingsIfNeeded()
            }
        ),
        .image: SourceSettingsBehavior(
            applyDefaultSourceSettings: {
                $0.applyImageSourceSettings(ImageConversionSettings())
            },
            applyStoredSourceSettings: { viewModel, sourceID in
                viewModel.applyStoredImageSourceSettings(for: sourceID)
            },
            persistCurrentSourceSettingsIfNeeded: {
                $0.persistCurrentImageSourceSettingsIfNeeded()
            }
        ),
        .audio: SourceSettingsBehavior(
            applyDefaultSourceSettings: {
                $0.applyAudioSourceSettings(AudioConversionSettings())
            },
            applyStoredSourceSettings: { viewModel, sourceID in
                viewModel.applyStoredAudioSourceSettings(for: sourceID)
            },
            persistCurrentSourceSettingsIfNeeded: {
                $0.persistCurrentAudioSourceSettingsIfNeeded()
            }
        )
    ]

    private var sourceSettingsBehavior: SourceSettingsBehavior {
        Self.sourceSettingsBehaviorByKind[self] ?? Self.sourceSettingsBehaviorByKind[.video]!
    }

    func applyDefaultSourceSettings(to viewModel: ContentViewModel) {
        sourceSettingsBehavior.applyDefaultSourceSettings(viewModel)
    }

    func applyStoredSourceSettings(sourceID: String, to viewModel: ContentViewModel) {
        sourceSettingsBehavior.applyStoredSourceSettings(viewModel, sourceID)
    }

    func persistCurrentSourceSettingsIfNeeded(in viewModel: ContentViewModel) {
        sourceSettingsBehavior.persistCurrentSourceSettingsIfNeeded(viewModel)
    }
}
