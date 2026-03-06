import Foundation

extension ContentViewModel {
    enum DeferredPersistenceAction {
        case videoFormatChange
        case videoOptionNormalization
        case audioFormatChange
        case audioOptionNormalization
    }

    struct DeferredPersistenceDescriptor {
        let taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let action: @MainActor (ContentViewModel) -> Void
    }

    func makeDeferredPersistenceDescriptor(
        taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        kind: MediaKind,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) -> DeferredPersistenceDescriptor {
        DeferredPersistenceDescriptor(
            taskKeyPath: taskKeyPath,
            action: { viewModel in
                action(viewModel)
                viewModel.persistCurrentSourceSettingsIfNeeded(for: kind)
            }
        )
    }

    func deferredPersistenceDescriptor(for action: DeferredPersistenceAction) -> DeferredPersistenceDescriptor {
        switch action {
        case .videoFormatChange:
            return makeDeferredPersistenceDescriptor(
                taskKeyPath: \.taskState.pendingVideoFormatChangeTask,
                kind: .video,
                action: { viewModel in
                    viewModel.refreshVideoCodecOptions()
                }
            )
        case .videoOptionNormalization:
            return makeDeferredPersistenceDescriptor(
                taskKeyPath: \.taskState.pendingVideoOptionNormalizationTask,
                kind: .video,
                action: { viewModel in
                    viewModel.normalizeVideoOptionDependencies()
                }
            )
        case .audioFormatChange:
            return makeDeferredPersistenceDescriptor(
                taskKeyPath: \.taskState.pendingAudioFormatChangeTask,
                kind: .audio,
                action: { viewModel in
                    viewModel.refreshAudioCodecOptions()
                }
            )
        case .audioOptionNormalization:
            return makeDeferredPersistenceDescriptor(
                taskKeyPath: \.taskState.pendingAudioOptionNormalizationTask,
                kind: .audio,
                action: { viewModel in
                    viewModel.normalizeAudioOptionDependencies()
                }
            )
        }
    }

    func scheduleDeferredPersistenceAction(_ action: DeferredPersistenceAction) {
        let descriptor = deferredPersistenceDescriptor(for: action)
        scheduleDeferredTask(descriptor.taskKeyPath, action: descriptor.action)
    }
}
