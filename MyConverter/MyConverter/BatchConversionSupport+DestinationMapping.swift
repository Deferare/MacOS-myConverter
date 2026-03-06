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
        using allocator: inout OutputPathUtilities.ReservedOutputAllocator
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent.isEmpty
            ? "output"
            : sourceURL.deletingPathExtension().lastPathComponent
        return allocator.reserveUniqueOutputURL(forBaseName: baseName, fileExtension: fileExtension)
    }

    static func assignAutoBatchDestinations(
        for sourceURLs: ArraySlice<URL>,
        fileExtension: String,
        allocator: inout OutputPathUtilities.ReservedOutputAllocator,
        destinationsBySourceID: inout [String: URL]
    ) {
        for sourceURL in sourceURLs {
            let destinationURL = uniqueBatchDestinationURL(
                for: sourceURL,
                fileExtension: fileExtension,
                using: &allocator
            )
            destinationsBySourceID[ContentViewModelSupport.sourceIdentifier(for: sourceURL)] = destinationURL
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
        var allocator = OutputPathUtilities.ReservedOutputAllocator(
            outputDirectory: outputDirectory,
            reservedPaths: preloadedReservedPaths ?? [],
            checksDirectoryContents: shouldCheckDirectoryContents
        )
        let firstSourceID = ContentViewModelSupport.sourceIdentifier(for: firstSourceURL)

        if let originalFirstDestinationURL = originalDestinationsBySourceID[firstSourceID] {
            let preferredFirstDestinationURL = normalizedDestinationURL(
                outputDirectory.appendingPathComponent(originalFirstDestinationURL.lastPathComponent),
                fileExtension: fileExtension
            )

            let firstDestinationURL: URL
            if allocator.reserve(preferredFirstDestinationURL) {
                firstDestinationURL = preferredFirstDestinationURL
            } else {
                firstDestinationURL = uniqueBatchDestinationURL(
                    for: firstSourceURL,
                    fileExtension: fileExtension,
                    using: &allocator
                )
            }

            remapped[firstSourceID] = firstDestinationURL
        }

        assignAutoBatchDestinations(
            for: sourceURLs.dropFirst(),
            fileExtension: fileExtension,
            allocator: &allocator,
            destinationsBySourceID: &remapped
        )

        return remapped
    }
}
