import Foundation

extension ContentViewModel {
    func removeProcessedSource(_ processedURL: URL, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)

        removeProcessedSource(
            processedURL,
            from: selectedSourceURLs(for: kind),
            assignSelection: { remainingURLs in
                assignSelection(remainingURLs, for: kind)
            },
            onSelectionEmptied: {
                resetCompatibilityStateForSelectionChange(for: kind)
                self[keyPath: descriptor.isAnalyzing] = false
                descriptor.applyPlaceholderCapabilities(self)
                scheduleCapabilityBootstrap()
            }
        )
    }

    func removeProcessedVideoSource(_ processedURL: URL) {
        removeProcessedSource(processedURL, for: .video)
    }

    func removeProcessedImageSource(_ processedURL: URL) {
        removeProcessedSource(processedURL, for: .image)
    }

    func removeProcessedAudioSource(_ processedURL: URL) {
        removeProcessedSource(processedURL, for: .audio)
    }
}
