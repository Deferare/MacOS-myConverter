import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SelectedFileReorderDropDelegate: DropDelegate {
    let targetURL: URL
    let availableURLPaths: Set<String>
    @Binding var draggedURL: URL?
    let isEnabled: Bool
    let onMove: (_ draggedURL: URL, _ targetURL: URL) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && info.hasItemsConforming(to: [UTType.text.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard isEnabled else { return }
        guard let draggedURL else { return }
        guard draggedURL.path != targetURL.path else { return }
        guard availableURLPaths.contains(draggedURL.path) else { return }
        guard availableURLPaths.contains(targetURL.path) else { return }

        onMove(draggedURL, targetURL)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isEnabled else { return nil }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedURL = nil
        return isEnabled
    }
}
