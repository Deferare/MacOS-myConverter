import Foundation
import SwiftUI

extension ContentViewModel {
    func moveSelectedSource(from draggedURL: URL, to targetURL: URL, for kind: MediaKind) {
        let workflow = selectionWorkflowDescriptor(for: kind)
        guard !workflow.isConversionRunning else { return }
        guard let reordered = reorderedURLsByMoving(
            draggedURL,
            to: targetURL,
            in: workflow.selectedSourceURLs
        ) else {
            return
        }

        workflow.assignSelection(reordered)
        refreshSelectionAfterPrimarySourceChange(reordered, using: workflow)
    }

    func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
    }
}
