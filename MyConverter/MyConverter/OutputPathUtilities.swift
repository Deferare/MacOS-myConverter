import Foundation

enum OutputPathUtilities {
    struct PreparedWorkingOutput: Sendable {
        let url: URL
        let strategy: WorkingOutputStrategy
    }

    nonisolated private static let maximumGeneratedFilenameComponentBytes = 180

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
        let filename = generatedFilenameComponent(
            baseName: baseName,
            fileExtension: fileExtension,
            suffix: "_working_\(UUID().uuidString)"
        )
        return workingDirectoryURL()
            .appendingPathComponent(filename)
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
        let rawBaseName = sourceURL.deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedGeneratedBaseName(rawBaseName, fallback: fallback)
        return boundedFilenameStem(
            normalized,
            maxUTF8Length: maximumGeneratedFilenameComponentBytes
        )
    }

    nonisolated private static func normalizedOutputComponents(
        baseName: String,
        fileExtension: String
    ) -> (baseName: String, fileExtension: String) {
        let effectiveBaseName = normalizedGeneratedBaseName(baseName, fallback: "output")
        let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return (effectiveBaseName, ext)
    }

    nonisolated private static func makeOutputCandidate(
        forBaseName baseName: String,
        fileExtension: String,
        in outputDirectory: URL,
        suffix: Int?
    ) -> URL {
        let filename = generatedFilenameComponent(
            baseName: baseName,
            fileExtension: fileExtension,
            suffix: suffix.map { "_converted_\($0)" } ?? ""
        )
        return outputDirectory.appendingPathComponent(filename)
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
        let stem = destinationURL.pathExtension.isEmpty
            ? destinationURL.lastPathComponent
            : destinationURL.deletingPathExtension().lastPathComponent
        return generatedFilenameComponent(
            baseName: normalizedGeneratedBaseName(stem, fallback: "output"),
            fileExtension: destinationURL.pathExtension,
            prefix: ".",
            suffix: ".myconverter-working-\(UUID().uuidString)"
        )
    }

    nonisolated private static func normalizedGeneratedBaseName(
        _ baseName: String,
        fallback: String
    ) -> String {
        var normalized = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            normalized = fallback
        }

        let generatedSuffixPatterns = [
            #"(?:_converted_\d+)+$"#,
            #"_working_[0-9A-Fa-f-]+$"#,
            #"\.myconverter-working-[0-9A-Fa-f-]+$"#
        ]

        var changed = true
        while changed {
            changed = false
            for pattern in generatedSuffixPatterns {
                if let range = normalized.range(of: pattern, options: .regularExpression) {
                    normalized.removeSubrange(range)
                    normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " ._-"))
                    changed = true
                }
            }
        }

        return normalized.isEmpty ? fallback : normalized
    }

    nonisolated private static func generatedFilenameComponent(
        baseName: String,
        fileExtension: String,
        prefix: String = "",
        suffix: String = ""
    ) -> String {
        let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let reservedBytes = prefix.utf8.count + suffix.utf8.count + (ext.isEmpty ? 0 : ext.utf8.count + 1)
        let maxStemBytes = max(32, maximumGeneratedFilenameComponentBytes - reservedBytes)
        let safeBaseName = boundedFilenameStem(baseName, maxUTF8Length: maxStemBytes)
        let filename = "\(prefix)\(safeBaseName)\(suffix)"
        guard !ext.isEmpty else { return filename }
        return "\(filename).\(ext)"
    }

    nonisolated private static func boundedFilenameStem(
        _ stem: String,
        maxUTF8Length: Int
    ) -> String {
        let trimmed = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf8.count > maxUTF8Length else { return trimmed }

        let hash = shortStableHash(for: trimmed)
        let separator = "-"
        let reservedBytes = hash.utf8.count + separator.utf8.count
        let prefixBytes = max(16, maxUTF8Length - reservedBytes)
        let safePrefix = utf8Prefix(of: trimmed, maxLength: prefixBytes)
        return "\(safePrefix)\(separator)\(hash)"
    }

    nonisolated private static func utf8Prefix(of value: String, maxLength: Int) -> String {
        guard maxLength > 0 else { return "" }

        var utf8Count = 0
        var endIndex = value.startIndex

        for character in value {
            let characterLength = String(character).utf8.count
            if utf8Count + characterLength > maxLength {
                break
            }
            utf8Count += characterLength
            endIndex = value.index(after: endIndex)
        }

        return String(value[..<endIndex])
    }

    nonisolated private static func shortStableHash(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        return String(hash, radix: 16, uppercase: false)
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
        if case let .outputSaveFailed(path, message) = self {
            return "Failed to save output to \(path): \(message)"
        }
        return nil
    }
}
