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
            apply: { MediaKind.video.refreshCodecOptions(in: $0) }
        )

        static let videoOptionNormalization = DeferredPersistenceAction(
            kind: .video,
            taskKeyPath: \.taskState.pendingVideoOptionNormalizationTask,
            apply: { MediaKind.video.normalizeOptionDependencies(in: $0) }
        )

        static let audioFormatChange = DeferredPersistenceAction(
            kind: .audio,
            taskKeyPath: \.taskState.pendingAudioFormatChangeTask,
            apply: { MediaKind.audio.refreshCodecOptions(in: $0) }
        )

        static let audioOptionNormalization = DeferredPersistenceAction(
            kind: .audio,
            taskKeyPath: \.taskState.pendingAudioOptionNormalizationTask,
            apply: { MediaKind.audio.normalizeOptionDependencies(in: $0) }
        )
    }

    func scheduleDeferredPersistenceAction(_ action: DeferredPersistenceAction) {
        scheduleDeferredTask(action.taskKeyPath) { viewModel in
            action.apply(to: viewModel)
            action.kind.persistCurrentSourceSettingsIfNeeded(in: viewModel)
        }
    }
}
