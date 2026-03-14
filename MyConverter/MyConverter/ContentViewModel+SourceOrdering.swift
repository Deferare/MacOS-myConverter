import Foundation
import SwiftUI

extension ContentViewModel {
    func moveSelectedSource(from draggedURL: URL, to targetURL: URL, for kind: MediaKind) {
        let descriptor = kind.mediaStateDescriptor
        guard !self[keyPath: descriptor.isConverting] else { return }
        let snapshot = mediaStateSnapshot(for: kind)
        guard let reordered = reorderedURLsByMoving(
            draggedURL,
            to: targetURL,
            in: snapshot.selectedSourceURLs
        ) else {
            return
        }

        assignSelection(reordered, for: kind)
        refreshSelectionAfterPrimarySourceChange(reordered, for: kind)
    }

    func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
    }
}
