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
        var reservedPaths: Set<String> = []
        assignAutoBatchDestinations(
            for: sourceURLs[...],
            fileExtension: fileExtension,
            outputDirectory: outputDirectory,
            reservedPaths: &reservedPaths,
            destinationsBySourceID: &selected
        )

        return selected
    }
}
