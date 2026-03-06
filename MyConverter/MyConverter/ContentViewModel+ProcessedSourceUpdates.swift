import Foundation

extension ContentViewModel {
    func removeProcessedSource(_ processedURL: URL, for kind: MediaKind) {
        removeProcessedSource(
            processedURL,
            from: selectedSourceURLs(for: kind),
            assignSelection: { remainingURLs in
                assignSelection(remainingURLs, for: kind)
            },
            onSelectionEmptied: {
                restoreIdleMediaState(for: kind)
            }
        )
    }
}
