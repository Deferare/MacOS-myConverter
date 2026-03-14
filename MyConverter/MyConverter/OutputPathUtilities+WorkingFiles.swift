import Foundation

extension OutputPathUtilities {
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
}
