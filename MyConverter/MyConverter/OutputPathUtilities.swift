import Foundation

enum OutputPathUtilities {
    private struct CachedFileFingerprint {
        let value: String
        let timestamp: UInt64
    }

    enum SaveOutputError: Error {
        case outputSaveFailed(path: String, message: String)
    }

    enum StagedInputError: Error {
        case stagingDirectoryCreationFailed(path: String, message: String)
        case stagingCopyFailed(sourcePath: String, destinationPath: String, message: String)
    }

    nonisolated private static let fileFingerprintCacheQueue = DispatchQueue(
        label: "myconverter.file.fingerprint.cache"
    )
    nonisolated(unsafe) private static var fileFingerprintCache: [String: CachedFileFingerprint] = [:]
    nonisolated private static let fileFingerprintCacheTTL: UInt64 = 500_000_000

    nonisolated static func fileFingerprint(for url: URL) -> String {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        let now = DispatchTime.now().uptimeNanoseconds

        if let cached = fileFingerprintCacheQueue.sync(execute: { fileFingerprintCache[path] }) {
            let age = now >= cached.timestamp ? now - cached.timestamp : 0
            if age < fileFingerprintCacheTTL {
                return cached.value
            }
        }

        let resourceValues = try? standardizedURL.resourceValues(
            forKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        let fileSize = resourceValues?.fileSize ?? -1
        let modificationInterval = resourceValues?.contentModificationDate?.timeIntervalSinceReferenceDate ?? -1
        let fingerprint = "\(path)|\(fileSize)|\(modificationInterval)"

        fileFingerprintCacheQueue.sync {
            fileFingerprintCache[path] = CachedFileFingerprint(
                value: fingerprint,
                timestamp: now
            )
        }

        return fingerprint
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
        reservedPaths: Set<String> = [],
        checksDirectoryContents: Bool = true
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
            let existsOnDisk = checksDirectoryContents && FileManager.default.fileExists(atPath: candidate.path)

            if !isReserved && !existsOnDisk {
                return candidate
            }
            index += 1
        }
    }

    nonisolated static func existingDirectoryEntryPaths(in directoryURL: URL) -> Set<String>? {
        guard let existingURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants]
        ) else {
            return nil
        }

        return Set(existingURLs.map { $0.standardizedFileURL.path })
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
