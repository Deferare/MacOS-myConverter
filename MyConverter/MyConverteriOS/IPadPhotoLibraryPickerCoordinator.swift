#if os(iOS)
import Foundation
import PhotosUI

extension IPadPhotoLibraryPicker {
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: IPadPhotoLibraryPicker

        init(parent: IPadPhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                parent.onCancel()
                return
            }

            parent.resolveTemporaryURLs(from: results) { [self] resolvedURLs in
                if resolvedURLs.isEmpty {
                    self.parent.onCancel()
                } else {
                    self.parent.onComplete(resolvedURLs)
                }
            }
        }
    }
}
#endif
