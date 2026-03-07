import Foundation

extension ContentViewModel {
    struct DeferredPersistenceMetadata {
        let kind: MediaKind
        let taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let apply: @MainActor (ContentViewModel) -> Void
    }

    struct DeferredPersistenceAction {
        let metadata: DeferredPersistenceMetadata

        init(
            kind: MediaKind,
            taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
            apply: @escaping @MainActor (ContentViewModel) -> Void
        ) {
            metadata = DeferredPersistenceMetadata(
                kind: kind,
                taskKeyPath: taskKeyPath,
                apply: apply
            )
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

        static let videoFormatChange = DeferredPersistenceAction(
            kind: .video,
            taskKeyPath: \.taskState.pendingVideoFormatChangeTask,
            apply: { $0.refreshVideoCodecOptions() }
        )

        static let videoOptionNormalization = DeferredPersistenceAction(
            kind: .video,
            taskKeyPath: \.taskState.pendingVideoOptionNormalizationTask,
            apply: { $0.normalizeVideoOptionDependencies() }
        )

        static let audioFormatChange = DeferredPersistenceAction(
            kind: .audio,
            taskKeyPath: \.taskState.pendingAudioFormatChangeTask,
            apply: { $0.refreshAudioCodecOptions() }
        )

        static let audioOptionNormalization = DeferredPersistenceAction(
            kind: .audio,
            taskKeyPath: \.taskState.pendingAudioOptionNormalizationTask,
            apply: { $0.normalizeAudioOptionDependencies() }
        )
    }

    func scheduleDeferredPersistenceAction(_ action: DeferredPersistenceAction) {
        scheduleDeferredTask(action.taskKeyPath) { viewModel in
            action.apply(to: viewModel)
            viewModel.persistCurrentSourceSettingsIfNeeded(for: action.kind)
        }
    }
}
