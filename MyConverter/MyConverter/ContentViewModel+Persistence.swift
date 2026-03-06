import Foundation

extension ContentViewModel {
    func scheduleVideoFormatChangeHandling() {
        scheduleDeferredTask(\.taskState.pendingVideoFormatChangeTask) { viewModel in
            viewModel.refreshVideoCodecOptions()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    func scheduleVideoOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.taskState.pendingVideoOptionNormalizationTask) { viewModel in
            viewModel.normalizeVideoOptionDependencies()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    func scheduleAudioFormatChangeHandling() {
        scheduleDeferredTask(\.taskState.pendingAudioFormatChangeTask) { viewModel in
            viewModel.refreshAudioCodecOptions()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    func scheduleAudioOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.taskState.pendingAudioOptionNormalizationTask) { viewModel in
            viewModel.normalizeAudioOptionDependencies()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }
}
