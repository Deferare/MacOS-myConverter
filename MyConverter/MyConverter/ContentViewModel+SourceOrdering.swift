import Foundation
import SwiftUI

extension ContentViewModel.MediaKind {
    func moveSelectedSource(
        from draggedURL: URL,
        to targetURL: URL,
        in viewModel: ContentViewModel
    ) {
        guard !isConverting(in: viewModel) else { return }
        let snapshot = mediaStateSnapshot(in: viewModel)
        guard let reordered = reorderedURLsByMoving(
            draggedURL,
            to: targetURL,
            in: snapshot.selectedSourceURLs
        ) else {
            return
        }

        assignSelection(reordered, in: viewModel)
        refreshSelectionAfterPrimarySourceChange(reordered, in: viewModel)
    }
}

private func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
    ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
}
