#if os(iOS)
import Foundation
import UIKit
import UniformTypeIdentifiers

@MainActor
final class IOSOutputDestinationCoordinator: NSObject, OutputDestinationCoordinator {
    static let shared = IOSOutputDestinationCoordinator()

    private var continuation: CheckedContinuation<OutputDestinationHandle?, Never>?

    private override init() {
        super.init()
    }

    func chooseOutputDestination(
        suggestedDirectory: URL,
        outputLabel _: String,
        fileCount _: Int
    ) async -> OutputDestinationHandle? {
        guard continuation == nil else { return nil }
        guard let presenter = topViewController() else { return nil }

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder],
            asCopy: false
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.directoryURL = suggestedDirectory

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            presenter.present(picker, animated: true)
        }
    }

    private func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .topMostPresentedViewController
    }
}

extension IOSOutputDestinationCoordinator: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
        continuation?.resume(returning: nil)
        continuation = nil
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        controller.dismiss(animated: true)
        let handle = urls.first.map { OutputDestinationHandle(url: $0) }
        continuation?.resume(returning: handle)
        continuation = nil
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostPresentedViewController
        }
        return self
    }
}
#endif
