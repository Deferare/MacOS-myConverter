import Foundation

extension ContentViewModel {
    func moveSelectedSource(from draggedURL: URL, to targetURL: URL, for kind: MediaKind) {
        let workflow = selectionWorkflowDescriptor(for: kind)

        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: workflow.isConversionRunning,
            currentPrimaryURL: workflow.currentPrimaryURL,
            selectedSourceURLs: workflow.selectedSourceURLs,
            assignSelection: workflow.assignSelection,
            cancelAnalysisTask: workflow.cancelAnalysisTask,
            resetCompatibilityState: workflow.resetCompatibilityState,
            applyStoredSettingsForSourceID: workflow.applyStoredSettingsForSourceID,
            analyzeSelection: workflow.analyzeSelection
        )
    }

    func moveSelectedSource(
        from draggedURL: URL,
        to targetURL: URL,
        isConversionRunning: Bool,
        currentPrimaryURL: URL?,
        selectedSourceURLs: [URL],
        assignSelection: ([URL]) -> Void,
        cancelAnalysisTask: () -> Void,
        resetCompatibilityState: () -> Void,
        applyStoredSettingsForSourceID: (String) -> Void,
        analyzeSelection: ([URL]) -> Void
    ) {
        guard !isConversionRunning else { return }
        let previousPrimaryID = currentPrimaryURL.map(sourceIdentifier(for:))
        guard let reordered = reorderedURLsByMoving(draggedURL, to: targetURL, in: selectedSourceURLs) else {
            return
        }

        assignSelection(reordered)

        guard let newPrimarySourceURL = reordered.first else { return }
        guard sourceIdentifier(for: newPrimarySourceURL) != previousPrimaryID else { return }

        cancelAnalysisTask()
        resetCompatibilityState()

        let sourceID = sourceIdentifier(for: newPrimarySourceURL)
        applyStoredSettingsForSourceID(sourceID)
        analyzeSelection(reordered)
    }

    func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
    }
}
