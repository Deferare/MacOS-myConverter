import Foundation

enum OutputPathUtilities {
    private struct CachedFileFingerprint {
        let value: String
        let timestamp: UInt64
    }

    struct ReservedOutputAllocator {
        private let outputDirectory: URL
        private let checksDirectoryContents: Bool
        private var reservedPaths: Set<String>
        private var nextSuffixByBaseKey: [String: Int]

        nonisolated
        init(
            outputDirectory: URL,
            reservedPaths: Set<String> = [],
            checksDirectoryContents: Bool = true
        ) {
            self.outputDirectory = outputDirectory
            self.checksDirectoryContents = checksDirectoryContents
            self.reservedPaths = reservedPaths
            self.nextSuffixByBaseKey = Self.makeNextSuffixIndex(from: reservedPaths)
        }

        nonisolated
        mutating func reserve(_ url: URL) -> Bool {
            let standardizedPath = url.standardizedFileURL.path
            guard !reservedPaths.contains(standardizedPath) else {
                return false
            }

            if checksDirectoryContents && FileManager.default.fileExists(atPath: url.path) {
                return false
            }

            reservedPaths.insert(standardizedPath)
            registerReservedBaseName(
                url.deletingPathExtension().lastPathComponent,
                fileExtension: url.pathExtension,
                nextSuffix: 1
            )
            return true
        }

        nonisolated
        mutating func reserveUniqueOutputURL(
            forBaseName baseName: String,
            fileExtension: String
        ) -> URL {
            let (effectiveBaseName, ext) = OutputPathUtilities.normalizedOutputComponents(
                baseName: baseName,
                fileExtension: fileExtension
            )
            let baseKey = Self.baseKey(forBaseName: effectiveBaseName, fileExtension: ext)
            var suffix = nextSuffixByBaseKey[baseKey] ?? 0

            while true {
                let candidate = OutputPathUtilities.makeOutputCandidate(
                    forBaseName: effectiveBaseName,
                    fileExtension: ext,
                    in: outputDirectory,
                    suffix: suffix == 0 ? nil : suffix
                )

                if reserveCandidate(candidate, baseKey: baseKey, nextSuffix: suffix + 1) {
                    return candidate
                }

                suffix += 1
            }
        }

        nonisolated
        private mutating func reserveCandidate(
            _ candidate: URL,
            baseKey: String,
            nextSuffix: Int
        ) -> Bool {
            let standardizedPath = candidate.standardizedFileURL.path
            guard !reservedPaths.contains(standardizedPath) else {
                return false
            }

            if checksDirectoryContents && FileManager.default.fileExists(atPath: candidate.path) {
                return false
            }

            reservedPaths.insert(standardizedPath)
            nextSuffixByBaseKey[baseKey] = max(nextSuffixByBaseKey[baseKey] ?? 0, nextSuffix)
            return true
        }

        nonisolated
        private mutating func registerReservedBaseName(
            _ baseName: String,
            fileExtension: String,
            nextSuffix: Int
        ) {
            let (effectiveBaseName, ext) = OutputPathUtilities.normalizedOutputComponents(
                baseName: baseName,
                fileExtension: fileExtension
            )
            let baseKey = Self.baseKey(forBaseName: effectiveBaseName, fileExtension: ext)
            nextSuffixByBaseKey[baseKey] = max(nextSuffixByBaseKey[baseKey] ?? 0, nextSuffix)
        }

        nonisolated
        private static func makeNextSuffixIndex(from reservedPaths: Set<String>) -> [String: Int] {
            var indexByBaseKey: [String: Int] = [:]
            indexByBaseKey.reserveCapacity(reservedPaths.count)

            for path in reservedPaths {
                let reservedURL = URL(fileURLWithPath: path)
                let baseName = reservedURL.deletingPathExtension().lastPathComponent
                let ext = reservedURL.pathExtension
                let baseKey = baseKey(forBaseName: baseName, fileExtension: ext)
                indexByBaseKey[baseKey] = max(indexByBaseKey[baseKey] ?? 0, 1)
            }

            return indexByBaseKey
        }

        nonisolated
        private static func baseKey(forBaseName baseName: String, fileExtension: String) -> String {
            let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return "\(baseName)|\(ext)"
        }
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
        var allocator = ReservedOutputAllocator(
            outputDirectory: outputDirectory,
            reservedPaths: reservedPaths,
            checksDirectoryContents: checksDirectoryContents
        )
        return allocator.reserveUniqueOutputURL(forBaseName: baseName, fileExtension: fileExtension)
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

    nonisolated private static func normalizedOutputComponents(
        baseName: String,
        fileExtension: String
    ) -> (baseName: String, fileExtension: String) {
        let trimmedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveBaseName = trimmedBaseName.isEmpty ? "output" : trimmedBaseName
        let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return (effectiveBaseName, ext)
    }

    nonisolated private static func makeOutputCandidate(
        forBaseName baseName: String,
        fileExtension: String,
        in outputDirectory: URL,
        suffix: Int?
    ) -> URL {
        let resolvedBaseName: String
        if let suffix {
            resolvedBaseName = "\(baseName)_converted_\(suffix)"
        } else {
            resolvedBaseName = baseName
        }

        if fileExtension.isEmpty {
            return outputDirectory.appendingPathComponent(resolvedBaseName)
        }

        return outputDirectory.appendingPathComponent("\(resolvedBaseName).\(fileExtension)")
    }
}
