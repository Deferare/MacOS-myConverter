import AppKit
import Foundation
import UniformTypeIdentifiers

extension BatchConversionSupport {
    static func selectDestinationURLs(
        for sourceURLs: [URL],
        fileExtension: String,
        outputLabel: String
    ) -> [String: URL]? {
        guard let firstSourceURL = sourceURLs.first else {
            return [:]
        }

        guard let firstDestinationURL = presentSavePanel(
            for: firstSourceURL,
            fileExtension: fileExtension,
            outputLabel: outputLabel,
            currentIndex: 1,
            totalCount: sourceURLs.count
        ) else {
            return nil
        }

        let firstSourceID = ContentViewModelSupport.sourceIdentifier(for: firstSourceURL)
        var selected: [String: URL] = [firstSourceID: firstDestinationURL]

        guard sourceURLs.count > 1 else {
            return selected
        }

        let outputDirectory = firstDestinationURL.deletingLastPathComponent()
        var reservedPaths: Set<String> = [firstDestinationURL.standardizedFileURL.path]
        assignAutoBatchDestinations(
            for: sourceURLs.dropFirst(),
            fileExtension: fileExtension,
            outputDirectory: outputDirectory,
            reservedPaths: &reservedPaths,
            destinationsBySourceID: &selected
        )

        return selected
    }

    static func presentSavePanel(
        for sourceURL: URL,
        fileExtension: String,
        outputLabel: String,
        currentIndex: Int,
        totalCount: Int
    ) -> URL? {
        let panel = NSSavePanel()
        let suggestedURL = OutputPathUtilities.uniqueOutputURL(
            for: sourceURL,
            fileExtension: fileExtension,
            in: sourceURL.deletingLastPathComponent()
        )

        panel.canCreateDirectories = true
        panel.canSelectHiddenExtension = true
        panel.isExtensionHidden = false
        panel.directoryURL = suggestedURL.deletingLastPathComponent()
        panel.nameFieldStringValue = suggestedURL.lastPathComponent
        panel.prompt = "Save"
        panel.title = totalCount > 1
            ? "Save \(outputLabel) Output \(currentIndex)/\(totalCount)"
            : "Save \(outputLabel) Output"
        panel.message = totalCount > 1
            ? "Choose where to save the first file. Remaining files will be saved to the same folder."
            : "Choose where to save \(sourceURL.lastPathComponent)."

        if let contentType = UTType(filenameExtension: fileExtension) {
            panel.allowedContentTypes = [contentType]
        }

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return nil
        }

        return normalizedDestinationURL(selectedURL, fileExtension: fileExtension)
    }
}
