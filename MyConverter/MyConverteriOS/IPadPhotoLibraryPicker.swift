#if os(iOS)
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct IPadPhotoLibraryPicker: UIViewControllerRepresentable {
    let kind: ContentViewModel.MediaKind
    let onComplete: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = pickerFilter(for: kind)
        configuration.selectionLimit = 0
        configuration.preferredAssetRepresentationMode = .current

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    private func pickerFilter(for kind: ContentViewModel.MediaKind) -> PHPickerFilter? {
        switch kind {
        case .image:
            return .images
        case .video:
            return .videos
        case .audio:
            return nil
        }
    }

    private func preferredTypeIdentifier(for provider: NSItemProvider) -> String? {
        let candidates: [String]

        switch kind {
        case .image:
            candidates = [UTType.image.identifier]
        case .video:
            candidates = [UTType.movie.identifier, UTType.video.identifier, UTType.audiovisualContent.identifier]
        case .audio:
            candidates = [UTType.audio.identifier]
        }

        if let matchingIdentifier = candidates.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) {
            return matchingIdentifier
        }

        return provider.registeredTypeIdentifiers.first
    }

    private func resolveTemporaryURLs(
        from results: [PHPickerResult],
        completion: @escaping ([URL]) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var resolvedURLs: [URL] = []

        for result in results {
            group.enter()
            resolveTemporaryURL(from: result.itemProvider) { url in
                if let url {
                    lock.lock()
                    resolvedURLs.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(resolvedURLs)
        }
    }

    private func resolveTemporaryURL(from provider: NSItemProvider, completion: @escaping (URL?) -> Void) {
        guard let typeIdentifier = preferredTypeIdentifier(for: provider) else {
            completion(nil)
            return
        }

        copyFileRepresentation(from: provider, typeIdentifier: typeIdentifier) { copiedURL in
            if let copiedURL {
                completion(copiedURL)
                return
            }

            copyDataRepresentation(from: provider, typeIdentifier: typeIdentifier, completion: completion)
        }
    }

    private func copyFileRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        completion: @escaping (URL?) -> Void
    ) {
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { sourceURL, error in
            guard let sourceURL else {
                _ = error
                completion(nil)
                return
            }

            do {
                let destinationURL = try makeTemporaryImportURL(
                    sourceURL: sourceURL,
                    typeIdentifier: typeIdentifier
                )
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                completion(destinationURL)
            } catch {
                completion(nil)
            }
        }
    }

    private func copyDataRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        completion: @escaping (URL?) -> Void
    ) {
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
            guard let data else {
                _ = error
                completion(nil)
                return
            }

            do {
                let destinationURL = try makeTemporaryImportURL(sourceURL: nil, typeIdentifier: typeIdentifier)
                try data.write(to: destinationURL, options: .atomic)
                completion(destinationURL)
            } catch {
                completion(nil)
            }
        }
    }

    private func makeTemporaryImportURL(
        sourceURL: URL?,
        typeIdentifier: String
    ) throws -> URL {
        let fileManager = FileManager.default
        let importDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PhotoLibraryImports", isDirectory: true)

        try fileManager.createDirectory(
            at: importDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileExtension = resolvedFileExtension(for: sourceURL, typeIdentifier: typeIdentifier)
        let filename = UUID().uuidString

        if let fileExtension {
            return importDirectory
                .appendingPathComponent(filename)
                .appendingPathExtension(fileExtension)
        }

        return importDirectory.appendingPathComponent(filename)
    }

    private func resolvedFileExtension(for sourceURL: URL?, typeIdentifier: String) -> String? {
        let existingExtension = sourceURL?.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingExtension, !existingExtension.isEmpty {
            return existingExtension
        }

        return UTType(importedAs: typeIdentifier).preferredFilenameExtension ?? fallbackFileExtension(for: kind)
    }

    private func fallbackFileExtension(for kind: ContentViewModel.MediaKind) -> String {
        switch kind {
        case .image:
            return "jpg"
        case .video:
            return "mov"
        case .audio:
            return "m4a"
        }
    }
}

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
