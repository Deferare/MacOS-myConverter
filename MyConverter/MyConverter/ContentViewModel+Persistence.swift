import Foundation

extension ContentViewModel {
    func scheduleVideoFormatChangeHandling() {
        scheduleDeferredTask(\.pendingVideoFormatChangeTask) { viewModel in
            viewModel.refreshVideoCodecOptions()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    func scheduleVideoOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.pendingVideoOptionNormalizationTask) { viewModel in
            viewModel.normalizeVideoOptionDependencies()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    func scheduleAudioFormatChangeHandling() {
        scheduleDeferredTask(\.pendingAudioFormatChangeTask) { viewModel in
            viewModel.refreshAudioCodecOptions()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    func scheduleAudioOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.pendingAudioOptionNormalizationTask) { viewModel in
            viewModel.normalizeAudioOptionDependencies()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }
}
