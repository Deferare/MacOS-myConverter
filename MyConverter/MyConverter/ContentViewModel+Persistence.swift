import Foundation

extension ContentViewModel {
    struct DeferredPersistenceMetadata {
        let kind: MediaKind
        let taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let apply: @MainActor (ContentViewModel) -> Void
    }

    enum DeferredPersistenceAction {
        case videoFormatChange
        case videoOptionNormalization
        case audioFormatChange
        case audioOptionNormalization

        var metadata: DeferredPersistenceMetadata {
            switch self {
            case .videoFormatChange:
                return DeferredPersistenceMetadata(
                    kind: .video,
                    taskKeyPath: \.taskState.pendingVideoFormatChangeTask,
                    apply: { $0.refreshVideoCodecOptions() }
                )
            case .videoOptionNormalization:
                return DeferredPersistenceMetadata(
                    kind: .video,
                    taskKeyPath: \.taskState.pendingVideoOptionNormalizationTask,
                    apply: { $0.normalizeVideoOptionDependencies() }
                )
            case .audioFormatChange:
                return DeferredPersistenceMetadata(
                    kind: .audio,
                    taskKeyPath: \.taskState.pendingAudioFormatChangeTask,
                    apply: { $0.refreshAudioCodecOptions() }
                )
            case .audioOptionNormalization:
                return DeferredPersistenceMetadata(
                    kind: .audio,
                    taskKeyPath: \.taskState.pendingAudioOptionNormalizationTask,
                    apply: { $0.normalizeAudioOptionDependencies() }
                )
            }
        }

        var kind: MediaKind {
            metadata.kind
        }

        var taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?> {
            metadata.taskKeyPath
        }

        @MainActor
        func apply(to viewModel: ContentViewModel) {
            metadata.apply(viewModel)
        }
    }

    func scheduleDeferredPersistenceAction(_ action: DeferredPersistenceAction) {
        scheduleDeferredTask(action.taskKeyPath) { viewModel in
            action.apply(to: viewModel)
            viewModel.persistCurrentSourceSettingsIfNeeded(for: action.kind)
        }
    }
}
