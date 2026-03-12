import Foundation

extension OutputPathUtilities {
    nonisolated private static let cachedWorkingDirectoryURL: URL = {
        resolveWorkingDirectoryURL()
    }()

    nonisolated static func stageInputURL(for sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let stagingDirectory = workingDirectoryURL().appendingPathComponent("FFmpegInput", isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: stagingDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw StagedInputError.stagingDirectoryCreationFailed(
                path: stagingDirectory.path,
                message: error.localizedDescription
            )
        }

        let baseName = sourceBaseName(for: sourceURL, fallback: "input")
        var stagedURL = stagingDirectory.appendingPathComponent("\(baseName)_\(UUID().uuidString)")
        if !sourceURL.pathExtension.isEmpty {
            stagedURL.appendPathExtension(sourceURL.pathExtension)
        }

        do {
            return try SecurityScopedResourceAccess.withAccess(to: sourceURL) {
                do {
                    // Hard links avoid copying large media files when the source is on the same volume.
                    try fileManager.linkItem(at: sourceURL, to: stagedURL)
                } catch {
                    if fileManager.fileExists(atPath: stagedURL.path) {
                        try? fileManager.removeItem(at: stagedURL)
                    }
                    try fileManager.copyItem(at: sourceURL, to: stagedURL)
                }
                return stagedURL
            }
        } catch {
            throw StagedInputError.stagingCopyFailed(
                sourcePath: sourceURL.path,
                destinationPath: stagedURL.path,
                message: error.localizedDescription
            )
        }
    }

    nonisolated static func removeFileIfExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
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
                try FileManager.default.moveItem(at: sourceURL, to: coordinatedDestinationURL)
            } catch {
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: coordinatedDestinationURL)
                    try? FileManager.default.removeItem(at: sourceURL)
                } catch {
                    fileOperationError = error
                }
            }
        }

        if let coordinationError {
            throw SaveOutputError.outputSaveFailed(
                path: destinationURL.path,
                message: coordinationError.localizedDescription
            )
        }

        if let fileOperationError {
            throw SaveOutputError.outputSaveFailed(
                path: destinationURL.path,
                message: fileOperationError.localizedDescription
            )
        }

        return destinationURL
        #else
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                try? FileManager.default.removeItem(at: sourceURL)
                return destinationURL
            } catch {
                throw SaveOutputError.outputSaveFailed(
                    path: destinationURL.path,
                    message: error.localizedDescription
                )
            }
        }
        #endif
    }

    nonisolated static func workingDirectoryURL() -> URL {
        let cached = cachedWorkingDirectoryURL
        if ensureDirectoryExists(cached) {
            return cached
        }
        return resolveWorkingDirectoryURL()
    }

    nonisolated private static func resolveWorkingDirectoryURL() -> URL {
        let fileManager = FileManager.default

        if let appSupportDirectory = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let identifier = Bundle.main.bundleIdentifier ?? "MyConverter"
            let workingDirectory = appSupportDirectory
                .appendingPathComponent(identifier, isDirectory: true)
                .appendingPathComponent("Working", isDirectory: true)
            if ensureDirectoryExists(workingDirectory) {
                return workingDirectory
            }
        }

        let fallbackDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("MyConverterWorking", isDirectory: true)
        _ = ensureDirectoryExists(fallbackDirectory)
        return fallbackDirectory
    }

    nonisolated static func ensureDirectoryExists(_ url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return true
        } catch {
            return false
        }
    }
}
