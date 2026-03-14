import Foundation

extension OutputPathUtilities {
    nonisolated static func removeFileIfExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    nonisolated static func saveOutputError(
        at destinationURL: URL,
        _ error: Error
    ) -> SaveOutputError {
        .outputSaveFailed(
            path: destinationURL.path,
            message: error.localizedDescription
        )
    }

    nonisolated static func moveItemOrCopyFallback(
        from sourceURL: URL,
        to destinationURL: URL,
        using fileManager: FileManager = .default
    ) throws -> URL {
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            try? fileManager.removeItem(at: sourceURL)
            return destinationURL
        }
    }

    nonisolated static func saveConvertedOutput(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        if sourceURL.path == destinationURL.path {
            return destinationURL
        }

        try removeFileIfExists(at: destinationURL)

        #if os(iOS)
        var coordinationError: NSError?
        var fileOperationError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(writingItemAt: destinationURL, options: [], error: &coordinationError) { coordinatedDestinationURL in
            do {
                _ = try moveItemOrCopyFallback(
                    from: sourceURL,
                    to: coordinatedDestinationURL
                )
            } catch {
                fileOperationError = error
            }
        }

        if let coordinationError {
            throw saveOutputError(at: destinationURL, coordinationError)
        }

        if let fileOperationError {
            throw saveOutputError(at: destinationURL, fileOperationError)
        }

        return destinationURL
        #else
        do {
            return try moveItemOrCopyFallback(from: sourceURL, to: destinationURL)
        } catch {
            throw saveOutputError(at: destinationURL, error)
        }
        #endif
    }
}
