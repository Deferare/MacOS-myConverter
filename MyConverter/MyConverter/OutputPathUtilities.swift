import Foundation

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
}
