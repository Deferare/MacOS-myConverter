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
        allocator.reserveUniqueOutputURL(
            forBaseName: OutputPathUtilities.sourceBaseName(for: sourceURL, fallback: "output"),
            fileExtension: fileExtension
        )
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

}
