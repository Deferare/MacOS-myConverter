#if os(iOS)
import Foundation
import PhotosUI
import UniformTypeIdentifiers

extension IPadPhotoLibraryPicker {
    func preferredTypeIdentifier(for provider: NSItemProvider) -> String? {
        if let matchingIdentifier = kind.preferredPhotoLibraryItemTypeIdentifiers.first(
            where: { provider.hasItemConformingToTypeIdentifier($0) }
        ) {
            return matchingIdentifier
        }

        return provider.registeredTypeIdentifiers.first
    }

    func resolveTemporaryURLs(
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

    func resolveTemporaryURL(from provider: NSItemProvider, completion: @escaping (URL?) -> Void) {
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

    func copyFileRepresentation(
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

    func copyDataRepresentation(
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

    func makeTemporaryImportURL(
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

    func resolvedFileExtension(for sourceURL: URL?, typeIdentifier: String) -> String? {
        let existingExtension = sourceURL?.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingExtension, !existingExtension.isEmpty {
            return existingExtension
        }

        return UTType(importedAs: typeIdentifier).preferredFilenameExtension ??
            kind.temporaryImportFallbackFileExtension
    }
}
#endif
