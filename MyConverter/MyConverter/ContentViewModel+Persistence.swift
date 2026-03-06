import Foundation

extension ContentViewModel {
    enum DeferredPersistenceAction {
        case videoFormatChange
        case videoOptionNormalization
        case audioFormatChange
        case audioOptionNormalization

        var kind: MediaKind {
            switch self {
            case .videoFormatChange, .videoOptionNormalization:
                return .video
            case .audioFormatChange, .audioOptionNormalization:
                return .audio
            }
        }

        var taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?> {
            switch self {
            case .videoFormatChange:
                return \.taskState.pendingVideoFormatChangeTask
            case .videoOptionNormalization:
                return \.taskState.pendingVideoOptionNormalizationTask
            case .audioFormatChange:
                return \.taskState.pendingAudioFormatChangeTask
            case .audioOptionNormalization:
                return \.taskState.pendingAudioOptionNormalizationTask
            }
        }

        @MainActor
        func apply(to viewModel: ContentViewModel) {
            switch self {
            case .videoFormatChange:
                viewModel.refreshVideoCodecOptions()
            case .videoOptionNormalization:
                viewModel.normalizeVideoOptionDependencies()
            case .audioFormatChange:
                viewModel.refreshAudioCodecOptions()
            case .audioOptionNormalization:
                viewModel.normalizeAudioOptionDependencies()
            }
        }
    }

    func scheduleDeferredPersistenceAction(_ action: DeferredPersistenceAction) {
        scheduleDeferredTask(action.taskKeyPath) { viewModel in
            action.apply(to: viewModel)
            viewModel.persistCurrentSourceSettingsIfNeeded(for: action.kind)
        }
    }
}
