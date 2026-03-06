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
                descriptor.resetSelectionCompatibilityState(self)
                self[keyPath: descriptor.isAnalyzing] = false
                descriptor.applyPlaceholderCapabilities(self)
                scheduleCapabilityBootstrap()
            }
        )
    }
}
