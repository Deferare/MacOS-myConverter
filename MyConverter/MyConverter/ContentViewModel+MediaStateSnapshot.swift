import Foundation

extension ContentViewModel {
    struct MediaStateSnapshot {
        let sourceURL: URL?
        let queuedSourceURLs: [URL]
        let convertedURLs: [URL]
        let convertedOutputURLsBySourceID: [String: URL]
        let processedSourceIDs: Set<String>
        let conversionErrorMessage: String?
        let compatibilityWarningMessage: String?
        let isAnalyzing: Bool
        let isConverting: Bool
        let progress: Double
        let currentBatchIndex: Int
        let totalBatchCount: Int
    }
}

extension ContentViewModel.MediaStateSnapshot {
    var selectedSourceURLs: [URL] {
        guard let sourceURL else { return [] }
        return [sourceURL] + queuedSourceURLs
    }

    var selectedFileCount: Int {
        sourceURL == nil ? 0 : queuedSourceURLs.count + 1
    }

    var displayedProgress: Double {
        let resolvedProgress = isConverting ? progress : 0
        return resolvedProgress < 0.01 ? 0 : resolvedProgress
    }

    var currentBatchItemProgress: Double {
        guard isConverting,
              currentBatchIndex > 0,
              totalBatchCount > 0 else {
            return 0
        }

        let completedBatchCount = Double(currentBatchIndex - 1)
        let totalBatchCount = Double(max(totalBatchCount, 1))
        let itemProgress = (progress * totalBatchCount) - completedBatchCount
        return ContentViewModelSupport.clampedProgress(itemProgress)
    }
}
