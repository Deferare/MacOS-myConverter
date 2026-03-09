import Foundation

extension ContentViewModel {
    struct PersistedSettingsState {
        var videoSettingsBySourceID: [String: VideoConversionSettings] = [:]
        var imageSettingsBySourceID: [String: ImageConversionSettings] = [:]
        var audioSettingsBySourceID: [String: AudioConversionSettings] = [:]
        var isApplyingVideoSettings = false
        var isApplyingImageSettings = false
        var isApplyingAudioSettings = false
        let videoStorageKey = "ContentViewModel.VideoSettingsBySource"
        let imageStorageKey = "ContentViewModel.ImageSettingsBySource"
        let audioStorageKey = "ContentViewModel.AudioSettingsBySource"
    }

    struct CapabilityWarmState {
        var warmedKinds: Set<MediaKind> = []
        var ffmpegPath: String?

        mutating func invalidateIfNeeded(for resolvedFFmpegPath: String?) {
            guard ffmpegPath != resolvedFFmpegPath else { return }
            ffmpegPath = resolvedFFmpegPath
            warmedKinds.removeAll()
        }

        mutating func markNeedsWarm(for kinds: [MediaKind]) {
            warmedKinds.subtract(kinds)
        }

        func pendingKinds(in requestedKinds: [MediaKind]) -> [MediaKind] {
            requestedKinds.filter { !warmedKinds.contains($0) }
        }

        mutating func markWarmed(_ kinds: [MediaKind], ffmpegPath: String?) {
            self.ffmpegPath = ffmpegPath
            warmedKinds.formUnion(kinds)
        }
    }

    struct TaskState {
        var sourceAnalysisTask: Task<Void, Never>?
        var conversionTask: Task<Void, Never>?
        var imageSourceAnalysisTask: Task<Void, Never>?
        var imageConversionTask: Task<Void, Never>?
        var audioSourceAnalysisTask: Task<Void, Never>?
        var audioConversionTask: Task<Void, Never>?
        var pendingVideoFormatChangeTask: Task<Void, Never>?
        var pendingVideoOptionNormalizationTask: Task<Void, Never>?
        var pendingAudioFormatChangeTask: Task<Void, Never>?
        var pendingAudioOptionNormalizationTask: Task<Void, Never>?
        var pendingVideoSettingsSaveTask: Task<Void, Never>?
        var pendingImageSettingsSaveTask: Task<Void, Never>?
        var pendingAudioSettingsSaveTask: Task<Void, Never>?
        var capabilityBootstrapTask: Task<Void, Never>?
    }
}
