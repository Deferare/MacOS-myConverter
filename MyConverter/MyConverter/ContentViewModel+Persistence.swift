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

    func deferredPersistenceDescriptor(for action: DeferredPersistenceAction) -> DeferredPersistenceDescriptor {
        switch action {
        case .videoFormatChange:
            return DeferredPersistenceDescriptor(
                taskKeyPath: \.taskState.pendingVideoFormatChangeTask,
                action: { viewModel in
                    viewModel.refreshVideoCodecOptions()
                    viewModel.persistCurrentSourceSettingsIfNeeded(for: .video)
                }
            )
        case .videoOptionNormalization:
            return DeferredPersistenceDescriptor(
                taskKeyPath: \.taskState.pendingVideoOptionNormalizationTask,
                action: { viewModel in
                    viewModel.normalizeVideoOptionDependencies()
                    viewModel.persistCurrentSourceSettingsIfNeeded(for: .video)
                }
            )
        case .audioFormatChange:
            return DeferredPersistenceDescriptor(
                taskKeyPath: \.taskState.pendingAudioFormatChangeTask,
                action: { viewModel in
                    viewModel.refreshAudioCodecOptions()
                    viewModel.persistCurrentSourceSettingsIfNeeded(for: .audio)
                }
            )
        case .audioOptionNormalization:
            return DeferredPersistenceDescriptor(
                taskKeyPath: \.taskState.pendingAudioOptionNormalizationTask,
                action: { viewModel in
                    viewModel.normalizeAudioOptionDependencies()
                    viewModel.persistCurrentSourceSettingsIfNeeded(for: .audio)
                }
            )
        }
    }

    func scheduleDeferredPersistenceAction(_ action: DeferredPersistenceAction) {
        let descriptor = deferredPersistenceDescriptor(for: action)
        scheduleDeferredTask(descriptor.taskKeyPath, action: descriptor.action)
    }
}
