import Foundation
import SwiftUI

extension ContentViewModel {
    func moveSelectedSource(from draggedURL: URL, to targetURL: URL, for kind: MediaKind) {
        let descriptor = kind.mediaStateDescriptor
        guard !self[keyPath: descriptor.isConverting] else { return }
        let snapshot = kind.mediaStateSnapshot(in: self)
        guard let reordered = reorderedURLsByMoving(
            draggedURL,
            to: targetURL,
            in: snapshot.selectedSourceURLs
        ) else {
            return
        }

        kind.assignSelection(reordered, in: self)
        refreshSelectionAfterPrimarySourceChange(reordered, for: kind)
    }

    func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
    }
}
