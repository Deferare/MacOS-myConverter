import AppKit
import Foundation
import UniformTypeIdentifiers

struct PreparedBatchConversionContext {
    let sourceURLs: [URL]
    let destinationURLsBySourceID: [String: URL]
    let stopAccessingBatchDirectory: () -> Void
}

enum BatchConversionSupport {
    private struct PreparedBatchDirectoryAccess {
        let destinationURLsBySourceID: [String: URL]
        let batchDirectoryURL: URL?
        let shouldStopAccessing: Bool
    }

    static func skippedFilesSummary(prefix: String, entries: [String]) -> String? {
        guard !entries.isEmpty else { return nil }
        return ([prefix] + entries).joined(separator: "\n")
    }

    static func prepareContext(
        sourceURLs: [URL],
        fileExtension: String,
        outputLabel: String
    ) -> PreparedBatchConversionContext? {
        guard var destinationURLsBySourceID = selectDestinationURLs(
            for: sourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel
        ) else {
            return nil
        }

        guard let batchAccess = prepareBatchDirectoryAccess(
            sourceURLs: sourceURLs,
            destinationURLsBySourceID: destinationURLsBySourceID,
            fileExtension: fileExtension,
            outputLabel: outputLabel
        ) else {
            return nil
        }

        destinationURLsBySourceID = batchAccess.destinationURLsBySourceID
        let stopAccessingBatchDirectory = {
            if batchAccess.shouldStopAccessing, let batchDirectoryURL = batchAccess.batchDirectoryURL {
                batchDirectoryURL.stopAccessingSecurityScopedResource()
            }
        }

        return PreparedBatchConversionContext(
            sourceURLs: sourceURLs,
            destinationURLsBySourceID: destinationURLsBySourceID,
            stopAccessingBatchDirectory: stopAccessingBatchDirectory
        )
    }

    static func destinationURL(
        for sourceURL: URL,
        in destinationURLsBySourceID: [String: URL],
        errorCode: Int
    ) throws -> URL {
        let sourceID = ContentViewModelSupport.sourceIdentifier(for: sourceURL)
        guard let destinationURL = destinationURLsBySourceID[sourceID] else {
            throw NSError(
                domain: "ContentViewModel",
                code: errorCode,
                userInfo: [NSLocalizedDescriptionKey: "Failed to resolve the selected output path."]
            )
        }
        return destinationURL
    }

    static func cleanupWorkingOutputIfNeeded(_ workingOutputURL: URL) {
        if FileManager.default.fileExists(atPath: workingOutputURL.path) {
            try? FileManager.default.removeItem(at: workingOutputURL)
        }
    }

    static func saveConvertedOutput(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        let destinationDirectoryURL = destinationURL.deletingLastPathComponent()

        return try SecurityScopedResourceAccess.withAccess(to: destinationURL) {
            try SecurityScopedResourceAccess.withAccess(to: destinationDirectoryURL) {
                try VideoConversionEngine.saveConvertedOutput(from: sourceURL, to: destinationURL)
            }
        }
    }

    private static func selectDestinationURLs(
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

    private static func presentSavePanel(
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

    private static func normalizedDestinationURL(_ url: URL, fileExtension: String) -> URL {
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

    private static func uniqueBatchDestinationURL(
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

    private static func assignAutoBatchDestinations(
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

    private static func remappedBatchDestinationURLs(
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

    private static func presentBatchDirectoryAccessPanel(
        suggestedDirectory: URL,
        outputLabel: String
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = suggestedDirectory
        panel.prompt = "Choose Folder"
        panel.title = "Choose \(outputLabel) Output Folder"
        panel.message = "Batch conversion needs folder access. Select a folder to save all converted files."

        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }

    private static func prepareBatchDirectoryAccess(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        fileExtension: String,
        outputLabel: String
    ) -> PreparedBatchDirectoryAccess? {
        guard sourceURLs.count > 1 else {
            return .init(
                destinationURLsBySourceID: destinationURLsBySourceID,
                batchDirectoryURL: nil,
                shouldStopAccessing: false
            )
        }

        let firstSourceID = ContentViewModelSupport.sourceIdentifier(for: sourceURLs[0])
        guard let firstDestinationURL = destinationURLsBySourceID[firstSourceID] else {
            return nil
        }

        let initialDirectoryURL = firstDestinationURL.deletingLastPathComponent()
        let initialAccess = initialDirectoryURL.startAccessingSecurityScopedResource()
        if initialAccess {
            return .init(
                destinationURLsBySourceID: destinationURLsBySourceID,
                batchDirectoryURL: initialDirectoryURL,
                shouldStopAccessing: true
            )
        }

        guard let grantedDirectoryURL = presentBatchDirectoryAccessPanel(
            suggestedDirectory: initialDirectoryURL,
            outputLabel: outputLabel
        ) else {
            return nil
        }

        let grantedAccess = grantedDirectoryURL.startAccessingSecurityScopedResource()
        guard grantedAccess else {
            return nil
        }

        let remappedDestinations = remappedBatchDestinationURLs(
            sourceURLs: sourceURLs,
            originalDestinationsBySourceID: destinationURLsBySourceID,
            outputDirectory: grantedDirectoryURL,
            fileExtension: fileExtension
        )

        return .init(
            destinationURLsBySourceID: remappedDestinations,
            batchDirectoryURL: grantedDirectoryURL,
            shouldStopAccessing: true
        )
    }
}
