import Foundation

extension ContentViewModel {
    func removeProcessedSource(_ processedURL: URL, for kind: MediaKind) {
        let workflow = selectionWorkflowDescriptor(for: kind)

        removeProcessedSource(
            processedURL,
            from: workflow.selectedSourceURLs,
            assignSelection: workflow.assignSelection,
            onSelectionEmptied: workflow.onSelectionEmptied
        )
    }
}
