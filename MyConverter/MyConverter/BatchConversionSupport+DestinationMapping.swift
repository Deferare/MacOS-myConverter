import Foundation

extension BatchConversionSupport {
    static func normalizedDestinationURL(_ url: URL, fileExtension: String) -> URL {
        let normalizedExtension = fileExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedExtension.isEmpty else {
            return url
        }

        if url.pathExtension.lowercased() == normalizedExtension {
            return url
        }

        if url.pathExtension.isEmpty {
            return url.appendingPathExtension(normalizedExtension)
        }

        return url.deletingPathExtension().appendingPathExtension(normalizedExtension)
    }

    static func uniqueBatchDestinationURL(
        for sourceURL: URL,
        fileExtension: String,
        in outputDirectory: URL,
        reservedPaths: Set<String>,
        checksDirectoryContents: Bool
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent.isEmpty
            ? "output"
            : sourceURL.deletingPathExtension().lastPathComponent
        return OutputPathUtilities.uniqueOutputURL(
            forBaseName: baseName,
            fileExtension: fileExtension,
            in: outputDirectory,
            reservedPaths: reservedPaths,
            checksDirectoryContents: checksDirectoryContents
        )
    }

    static func assignAutoBatchDestinations(
        for sourceURLs: ArraySlice<URL>,
        fileExtension: String,
        outputDirectory: URL,
        reservedPaths: inout Set<String>,
        checksDirectoryContents: Bool,
        destinationsBySourceID: inout [String: URL]
    ) {
        for sourceURL in sourceURLs {
            let destinationURL = uniqueBatchDestinationURL(
                for: sourceURL,
                fileExtension: fileExtension,
                in: outputDirectory,
                reservedPaths: reservedPaths,
                checksDirectoryContents: checksDirectoryContents
            )
            destinationsBySourceID[ContentViewModelSupport.sourceIdentifier(for: sourceURL)] = destinationURL
            reservedPaths.insert(destinationURL.standardizedFileURL.path)
        }
    }

    static func remappedBatchDestinationURLs(
        sourceURLs: [URL],
        originalDestinationsBySourceID: [String: URL],
        outputDirectory: URL,
        fileExtension: String
    ) -> [String: URL] {
        guard let firstSourceURL = sourceURLs.first else {
            return originalDestinationsBySourceID
        }

        var remapped: [String: URL] = [:]
        let preloadedReservedPaths = OutputPathUtilities.existingDirectoryEntryPaths(in: outputDirectory)
        let shouldCheckDirectoryContents = preloadedReservedPaths == nil
        var reservedPaths = preloadedReservedPaths ?? []
        let firstSourceID = ContentViewModelSupport.sourceIdentifier(for: firstSourceURL)

        if let originalFirstDestinationURL = originalDestinationsBySourceID[firstSourceID] {
            let preferredFirstDestinationURL = normalizedDestinationURL(
                outputDirectory.appendingPathComponent(originalFirstDestinationURL.lastPathComponent),
                fileExtension: fileExtension
            )
            let preferredFirstPath = preferredFirstDestinationURL.standardizedFileURL.path

            let firstDestinationURL: URL
            let preferredPathIsReserved = reservedPaths.contains(preferredFirstPath)
            let preferredPathExistsOnDisk =
                shouldCheckDirectoryContents &&
                FileManager.default.fileExists(atPath: preferredFirstDestinationURL.path)

            if preferredPathIsReserved || preferredPathExistsOnDisk {
                firstDestinationURL = uniqueBatchDestinationURL(
                    for: firstSourceURL,
                    fileExtension: fileExtension,
                    in: outputDirectory,
                    reservedPaths: reservedPaths,
                    checksDirectoryContents: shouldCheckDirectoryContents
                )
            } else {
                firstDestinationURL = preferredFirstDestinationURL
            }

            remapped[firstSourceID] = firstDestinationURL
            reservedPaths.insert(firstDestinationURL.standardizedFileURL.path)
        }

        assignAutoBatchDestinations(
            for: sourceURLs.dropFirst(),
            fileExtension: fileExtension,
            outputDirectory: outputDirectory,
            reservedPaths: &reservedPaths,
            checksDirectoryContents: shouldCheckDirectoryContents,
            destinationsBySourceID: &remapped
        )

        return remapped
    }
}
