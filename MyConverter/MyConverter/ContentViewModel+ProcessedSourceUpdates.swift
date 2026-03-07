import Foundation

extension ContentViewModel {
    func removeProcessedSource(_ processedURL: URL, for kind: MediaKind) {
        removeProcessedSource(processedURL, using: selectionWorkflowDescriptor(for: kind))
    }
}
