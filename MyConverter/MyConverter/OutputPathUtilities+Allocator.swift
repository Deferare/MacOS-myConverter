import Foundation

extension OutputPathUtilities {
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
            let preloadedReservedPaths = existingDirectoryEntryPaths(in: outputDirectory)
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

    nonisolated static func makeOutputCandidate(
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
}
