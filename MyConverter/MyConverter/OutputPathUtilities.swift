import Foundation

enum OutputPathUtilities {
    struct PreparedWorkingOutput: Sendable {
        let url: URL
        let strategy: WorkingOutputStrategy
    }

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
        static func preloaded(for outputDirectory: URL) -> Self {
            let preloadedReservedPaths = OutputPathUtilities.existingDirectoryEntryPaths(in: outputDirectory)
            return Self(
                outputDirectory: outputDirectory,
                reservedPaths: preloadedReservedPaths ?? [],
                checksDirectoryContents: preloadedReservedPaths == nil
            )
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
        let baseName = sourceBaseName(for: sourceURL, fallback: "output")
        let ext = fileExtension
        return workingDirectoryURL()
            .appendingPathComponent("\(baseName)_working_\(UUID().uuidString).\(ext)")
    }

    nonisolated static func prepareWorkingOutput(
        for sourceURL: URL,
        destinationURL: URL
    ) -> PreparedWorkingOutput {
        #if os(iOS)
        return PreparedWorkingOutput(
            url: temporaryOutputURL(
                for: sourceURL,
                fileExtension: destinationURL.pathExtension
            ),
            strategy: .workingDirectoryFallback
        )
        #else
        if let destinationAdjacent = destinationAdjacentTemporaryOutputURL(for: destinationURL) {
            return PreparedWorkingOutput(
                url: destinationAdjacent,
                strategy: .destinationAdjacent
            )
        }

        return PreparedWorkingOutput(
            url: temporaryOutputURL(
                for: sourceURL,
                fileExtension: destinationURL.pathExtension
            ),
            strategy: .workingDirectoryFallback
        )
        #endif
    }

    nonisolated static func commitPreparedOutput(
        from sourceURL: URL,
        to destinationURL: URL,
        strategy: WorkingOutputStrategy
    ) throws -> URL {
        let token = PerformanceSignpost.begin("FinalizeOutput", message: destinationURL.lastPathComponent)
        defer {
            PerformanceSignpost.end("FinalizeOutput", token: token, message: destinationURL.lastPathComponent)
        }

        let usesDestinationAdjacentRename =
            strategy == .destinationAdjacent &&
            sourceURL.deletingLastPathComponent().standardizedFileURL ==
            destinationURL.deletingLastPathComponent().standardizedFileURL

        if usesDestinationAdjacentRename {
            return try commitDestinationAdjacentOutput(
                from: sourceURL,
                to: destinationURL
            )
        }

        return try saveConvertedOutput(from: sourceURL, to: destinationURL)
    }

    nonisolated static func sourceBaseName(for sourceURL: URL, fallback: String) -> String {
        let baseName = sourceURL.deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return baseName.isEmpty ? fallback : baseName
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

    nonisolated private static func destinationAdjacentTemporaryOutputURL(
        for destinationURL: URL
    ) -> URL? {
        let outputDirectoryURL = destinationURL.deletingLastPathComponent()
        guard ensureDirectoryExists(outputDirectoryURL) else {
            return nil
        }

        let tempURL = outputDirectoryURL.appendingPathComponent(
            hiddenWorkingFilename(for: destinationURL)
        )

        do {
            let created = FileManager.default.createFile(
                atPath: tempURL.path,
                contents: Data(),
                attributes: nil
            )
            guard created else {
                return nil
            }
            try removeFileIfExists(at: tempURL)
            return tempURL
        } catch {
            try? removeFileIfExists(at: tempURL)
            return nil
        }
    }

    nonisolated private static func hiddenWorkingFilename(for destinationURL: URL) -> String {
        let filename = destinationURL.lastPathComponent
        if destinationURL.pathExtension.isEmpty {
            return ".\(filename).myconverter-working-\(UUID().uuidString)"
        }

        let stem = destinationURL.deletingPathExtension().lastPathComponent
        return ".\(stem).myconverter-working-\(UUID().uuidString).\(destinationURL.pathExtension)"
    }

    nonisolated private static func commitDestinationAdjacentOutput(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws -> URL {
        let fileManager = FileManager.default
        let originalExists = fileManager.fileExists(atPath: destinationURL.path)

        if originalExists {
            do {
                let replaced = try fileManager.replaceItemAt(
                    destinationURL,
                    withItemAt: sourceURL,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
                return replaced ?? destinationURL
            } catch {
                throw SaveOutputError.outputSaveFailed(
                    path: destinationURL.path,
                    message: error.localizedDescription
                )
            }
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            throw SaveOutputError.outputSaveFailed(
                path: destinationURL.path,
                message: error.localizedDescription
            )
        }
    }
}

extension OutputPathUtilities.SaveOutputError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .outputSaveFailed(path, message):
            return "Failed to save output to \(path): \(message)"
        }
    }
}
