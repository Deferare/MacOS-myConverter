import Foundation

extension BatchConversionSupport {
    nonisolated static func uniqueBatchDestinationURL(
        for sourceURL: URL,
        fileExtension: String,
        using allocator: inout OutputPathUtilities.ReservedOutputAllocator
    ) -> URL {
        allocator.reserveUniqueOutputURL(
            forBaseName: OutputPathUtilities.sourceBaseName(for: sourceURL, fallback: "output"),
            fileExtension: fileExtension
        )
    }

    nonisolated static func assignAutoBatchDestinations(
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
