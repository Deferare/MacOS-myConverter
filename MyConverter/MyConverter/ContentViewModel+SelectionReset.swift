import Foundation

extension ContentViewModel {
    func clearSelectedSource() {
        clearSelectedVideoSource()
    }

    func clearSelectedVideoSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&sourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                sourceURL = nil
                queuedSourceURLs = []
                resetVideoConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetVideoCompatibilityMessages()
                isAnalyzingSource = false
                currentVideoBatchIndex = 0
                totalVideoBatchCount = 0
            },
            resetFormatsAndSettings: {
                applyPlaceholderVideoCapabilities()
                applyStoredSettings(.init())
                scheduleCapabilityBootstrap()
            }
        )
    }

    func clearSelectedImageSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&imageSourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                imageSourceURL = nil
                queuedImageSourceURLs = []
                resetImageConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetImageCompatibilityState(resetMetadata: true)
                isAnalyzingImageSource = false
                currentImageBatchIndex = 0
                totalImageBatchCount = 0
            },
            resetFormatsAndSettings: {
                applyPlaceholderImageCapabilities()
                applyStoredImageSettings(.init())
                scheduleCapabilityBootstrap()
            }
        )
    }

    func clearSelectedAudioSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&audioSourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                audioSourceURL = nil
                queuedAudioSourceURLs = []
                resetAudioConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetAudioCompatibilityMessages()
                isAnalyzingAudioSource = false
                currentAudioBatchIndex = 0
                totalAudioBatchCount = 0
            },
            resetFormatsAndSettings: {
                applyPlaceholderAudioCapabilities()
                applyStoredAudioSettings(.init())
                scheduleCapabilityBootstrap()
            }
        )
    }
}
