import Foundation

extension ContentViewModel {
    func clearSelectedSourceState(
        cancelAnalysisTask: () -> Void,
        resetSelectionAndOutput: () -> Void,
        resetCompatibilityAndBatchState: () -> Void,
        resetFormatsAndSettings: () -> Void
    ) {
        cancelAnalysisTask()
        resetSelectionAndOutput()
        resetCompatibilityAndBatchState()
        resetFormatsAndSettings()
    }

    func resetVideoConversionOutputs() {
        convertedURL = nil
        convertedURLs = []
        conversionErrorMessage = nil
    }

    func resetImageConversionOutputs() {
        convertedImageURL = nil
        convertedImageURLs = []
        imageConversionErrorMessage = nil
    }

    func resetAudioConversionOutputs() {
        convertedAudioURL = nil
        convertedAudioURLs = []
        audioConversionErrorMessage = nil
    }

    func resetVideoCompatibilityMessages() {
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil
    }

    func resetImageCompatibilityState(resetMetadata: Bool) {
        if resetMetadata {
            imageSourceFrameCount = 0
            imageSourceHasAlpha = false
        }
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil
    }

    func resetAudioCompatibilityMessages() {
        audioSourceCompatibilityErrorMessage = nil
        audioSourceCompatibilityWarningMessage = nil
    }
}
