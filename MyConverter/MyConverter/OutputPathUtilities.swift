import Foundation

enum SecurityScopedResourceAccess {
    nonisolated static func withAccess<T>(
        to url: URL,
        operation: () throws -> T
    ) rethrows -> T {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    nonisolated static func withAccess<T>(
        to url: URL,
        operation: () async throws -> T
    ) async rethrows -> T {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation()
    }
}

enum OutputPathUtilities {
    enum SaveOutputError: Error {
        case outputSaveFailed(path: String, message: String)
    }

    enum StagedInputError: Error {
        case stagingDirectoryCreationFailed(path: String, message: String)
        case stagingCopyFailed(sourcePath: String, destinationPath: String, message: String)
    }

    nonisolated static func uniqueOutputURL(
        for sourceURL: URL,
        fileExtension: String,
        in outputDirectory: URL
    ) -> URL {
        uniqueOutputURL(
            forBaseName: sourceURL.deletingPathExtension().lastPathComponent,
            fileExtension: fileExtension,
            in: outputDirectory
        )
    }

    nonisolated static func uniqueOutputURL(
        forBaseName baseName: String,
        fileExtension: String,
        in outputDirectory: URL,
        reservedPaths: Set<String> = []
    ) -> URL {
        let trimmedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveBaseName = trimmedBaseName.isEmpty ? "output" : trimmedBaseName
        let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)

        func makeCandidate(suffix: Int?) -> URL {
            let resolvedBaseName: String
            if let suffix {
                resolvedBaseName = "\(effectiveBaseName)_converted_\(suffix)"
            } else {
                resolvedBaseName = effectiveBaseName
            }

            if ext.isEmpty {
                return outputDirectory.appendingPathComponent(resolvedBaseName)
            }
            return outputDirectory.appendingPathComponent("\(resolvedBaseName).\(ext)")
        }

        var index = 0
        while true {
            let candidate = makeCandidate(suffix: index == 0 ? nil : index)
            let standardizedPath = candidate.standardizedFileURL.path
            let isReserved = reservedPaths.contains(standardizedPath)
            let existsOnDisk = FileManager.default.fileExists(atPath: candidate.path)

            if !isReserved && !existsOnDisk {
                return candidate
            }
            index += 1
        }
    }

    nonisolated static func temporaryOutputURL(
        for sourceURL: URL,
        fileExtension: String
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = fileExtension
        return workingDirectoryURL()
            .appendingPathComponent("\(baseName)_working_\(UUID().uuidString).\(ext)")
    }

    nonisolated static func stageInputURL(for sourceURL: URL) throws -> URL {
        let stagingDirectory = workingDirectoryURL().appendingPathComponent("FFmpegInput", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
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

        let baseName = sourceURL.deletingPathExtension().lastPathComponent.isEmpty
            ? "input"
            : sourceURL.deletingPathExtension().lastPathComponent
        var stagedURL = stagingDirectory.appendingPathComponent("\(baseName)_\(UUID().uuidString)")
        if !sourceURL.pathExtension.isEmpty {
            stagedURL.appendPathExtension(sourceURL.pathExtension)
        }

        do {
            return try SecurityScopedResourceAccess.withAccess(to: sourceURL) {
                try FileManager.default.copyItem(at: sourceURL, to: stagedURL)
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
    }

    nonisolated private static func workingDirectoryURL() -> URL {
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

    nonisolated private static func ensureDirectoryExists(_ url: URL) -> Bool {
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
