#if os(iOS)
import Foundation
import PhotosUI
import SwiftUI

struct IPadPhotoLibraryPicker: UIViewControllerRepresentable {
    let kind: ContentViewModel.MediaKind
    let onComplete: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = kind.photoLibraryPickerFilter
        configuration.selectionLimit = 0
        configuration.preferredAssetRepresentationMode = .current

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}
#endif
