import Foundation

extension ContentViewModel {
    struct RetainedSecurityScopedURL {
        let url: URL
        let shouldStopAccessing: Bool
        var retainCount: Int
    }

    struct SecurityScopeState {
        var retainedByPath: [String: RetainedSecurityScopedURL] = [:]
        var pathsByKind: [MediaKind: Set<String>] = [:]
        var outputDirectoryPathByKind: [MediaKind: String] = [:]
        var outputDestinationHandleByKind: [MediaKind: OutputDestinationHandle] = [:]
    }

    struct PreparedSingleVideoSelection {
        let sourceID: String
        let sourceURL: URL
        let preparedSourceContext: VideoConversionEngine.PreparedSourceContext
    }

    struct SelectionPreparationState {
        var preparedSingleVideoSelection: PreparedSingleVideoSelection?
    }

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
        var ffmpegRuntimeIdentity: String?

        mutating func invalidateIfNeeded(for resolvedFFmpegRuntimeIdentity: String?) {
            guard ffmpegRuntimeIdentity != resolvedFFmpegRuntimeIdentity else { return }
            ffmpegRuntimeIdentity = resolvedFFmpegRuntimeIdentity
            warmedKinds.removeAll()
        }

        mutating func markNeedsWarm(for kinds: [MediaKind]) {
            warmedKinds.subtract(kinds)
        }

        func pendingKinds(in requestedKinds: [MediaKind]) -> [MediaKind] {
            requestedKinds.filter { !warmedKinds.contains($0) }
        }

        mutating func markWarmed(_ kinds: [MediaKind], ffmpegRuntimeIdentity: String?) {
            self.ffmpegRuntimeIdentity = ffmpegRuntimeIdentity
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
        var pendingVideoSelectionAnalysisTask: Task<Void, Never>?
        var pendingImageSelectionAnalysisTask: Task<Void, Never>?
        var pendingAudioSelectionAnalysisTask: Task<Void, Never>?
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
