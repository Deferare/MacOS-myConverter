import Foundation

extension BatchConversionSupport {
    static func selectDestinationURLs(
        for sourceURLs: [URL],
        fileExtension: String,
        outputLabel: String
    ) -> [String: URL]? {
        guard let firstSourceURL = sourceURLs.first else {
            return [:]
        }

        guard let outputDirectory = presentBatchDirectoryAccessPanel(
            suggestedDirectory: firstSourceURL.deletingLastPathComponent(),
            outputLabel: outputLabel,
            fileCount: sourceURLs.count
        ) else {
            return nil
        }

        var selected: [String: URL] = [:]
        let preloadedReservedPaths = OutputPathUtilities.existingDirectoryEntryPaths(in: outputDirectory)
        let shouldCheckDirectoryContents = preloadedReservedPaths == nil
        var allocator = OutputPathUtilities.ReservedOutputAllocator(
            outputDirectory: outputDirectory,
            reservedPaths: preloadedReservedPaths ?? [],
            checksDirectoryContents: shouldCheckDirectoryContents
        )
        assignAutoBatchDestinations(
            for: sourceURLs[...],
            fileExtension: fileExtension,
            allocator: &allocator,
            destinationsBySourceID: &selected
        )

        return selected
    }
}
