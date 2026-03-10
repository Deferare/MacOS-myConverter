import Foundation

extension BatchConversionSupport {
    static func selectDestinationURLs(
        for sourceURLs: [URL],
        fileExtension: String,
        outputLabel: String,
        preferredOutputDirectory: URL? = nil
    ) -> [String: URL]? {
        guard let firstSourceURL = sourceURLs.first else {
            return [:]
        }

        let outputDirectory: URL
        if let preferredOutputDirectory {
            outputDirectory = preferredOutputDirectory.standardizedFileURL
        } else {
            guard let selectedDirectory = presentBatchDirectoryAccessPanel(
                suggestedDirectory: firstSourceURL.deletingLastPathComponent(),
                outputLabel: outputLabel,
                fileCount: sourceURLs.count
            ) else {
                return nil
            }
            outputDirectory = selectedDirectory.standardizedFileURL
        }

        var selected: [String: URL] = [:]
        var allocator = OutputPathUtilities.ReservedOutputAllocator.preloaded(for: outputDirectory)
        assignAutoBatchDestinations(
            for: sourceURLs[...],
            fileExtension: fileExtension,
            allocator: &allocator,
            destinationsBySourceID: &selected
        )

        return selected
    }
}
