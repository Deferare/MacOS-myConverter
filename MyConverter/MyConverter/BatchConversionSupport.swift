import AppKit
import Foundation

struct PreparedBatchConversionContext {
    let sourceURLs: [URL]
    let destinationURLsBySourceID: [String: URL]
    let stopAccessingBatchDirectory: () -> Void
}

enum BatchConversionSupport {
    struct PreparedBatchDirectoryAccess {
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
        outputLabel: String,
        preferredOutputDirectory: URL? = nil
    ) -> PreparedBatchConversionContext? {
        guard var destinationURLsBySourceID = selectDestinationURLs(
            for: sourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel,
            preferredOutputDirectory: preferredOutputDirectory
        ) else {
            return nil
        }

        guard let batchAccess = prepareBatchDirectoryAccess(
            sourceURLs: sourceURLs,
            destinationURLsBySourceID: destinationURLsBySourceID
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
}
