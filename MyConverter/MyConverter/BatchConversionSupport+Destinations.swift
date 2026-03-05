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
        reservedPaths: Set<String>
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent.isEmpty
            ? "output"
            : sourceURL.deletingPathExtension().lastPathComponent
        return OutputPathUtilities.uniqueOutputURL(
            forBaseName: baseName,
            fileExtension: fileExtension,
            in: outputDirectory,
            reservedPaths: reservedPaths
        )
    }

    static func assignAutoBatchDestinations(
        for sourceURLs: ArraySlice<URL>,
        fileExtension: String,
        outputDirectory: URL,
        reservedPaths: inout Set<String>,
        destinationsBySourceID: inout [String: URL]
    ) {
        for sourceURL in sourceURLs {
            let destinationURL = uniqueBatchDestinationURL(
                for: sourceURL,
                fileExtension: fileExtension,
                in: outputDirectory,
                reservedPaths: reservedPaths
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
        var reservedPaths: Set<String> = []
        let firstSourceID = ContentViewModelSupport.sourceIdentifier(for: firstSourceURL)

        if let originalFirstDestinationURL = originalDestinationsBySourceID[firstSourceID] {
            let preferredFirstDestinationURL = normalizedDestinationURL(
                outputDirectory.appendingPathComponent(originalFirstDestinationURL.lastPathComponent),
                fileExtension: fileExtension
            )

            let firstDestinationURL: URL
            if FileManager.default.fileExists(atPath: preferredFirstDestinationURL.path) {
                firstDestinationURL = uniqueBatchDestinationURL(
                    for: firstSourceURL,
                    fileExtension: fileExtension,
                    in: outputDirectory,
                    reservedPaths: reservedPaths
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
            destinationsBySourceID: &remapped
        )

        return remapped
    }
}
