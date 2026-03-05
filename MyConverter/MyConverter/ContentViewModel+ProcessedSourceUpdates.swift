import Foundation

extension ContentViewModel {
    func removeProcessedVideoSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedVideoSourceURLs,
            assignSelection: assignVideoSelection(_:),
            onSelectionEmptied: {
                resetVideoCompatibilityMessages()
                isAnalyzingSource = false
                availableOutputFormats = VideoConversionEngine.defaultOutputFormats()
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    func removeProcessedImageSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedImageSourceURLs,
            assignSelection: assignImageSelection(_:),
            onSelectionEmptied: {
                resetImageCompatibilityState(resetMetadata: true)
                isAnalyzingImageSource = false
                availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    func removeProcessedAudioSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedAudioSourceURLs,
            assignSelection: assignAudioSelection(_:),
            onSelectionEmptied: {
                resetAudioCompatibilityMessages()
                isAnalyzingAudioSource = false
                availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }
}
