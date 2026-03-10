import AppKit
import Foundation

enum BatchConversionSupport {
    struct SelectedBatchDestinations {
        let destinationURLsBySourceID: [String: URL]
        let outputDirectoryURL: URL
    }

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
        guard let selectedDestinations = selectDestinationURLs(
            for: sourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel,
            preferredOutputDirectory: preferredOutputDirectory
        ) else {
            return nil
        }
        let destinationURLsBySourceID = selectedDestinations.destinationURLsBySourceID

        guard let batchAccess = prepareBatchDirectoryAccess(
            sourceURLs: sourceURLs,
            destinationURLsBySourceID: destinationURLsBySourceID
        ) else {
            return nil
        }

        let stopAccessingBatchDirectory = {
            if batchAccess.shouldStopAccessing, let batchDirectoryURL = batchAccess.batchDirectoryURL {
                batchDirectoryURL.stopAccessingSecurityScopedResource()
            }
        }

        let preparedSources = sourceURLs.compactMap { sourceURL -> PreparedSourceConversion? in
            let sourceID = ContentViewModelSupport.sourceIdentifier(for: sourceURL)
            guard let destinationURL = batchAccess.destinationURLsBySourceID[sourceID] else {
                return nil
            }

            let preparedWorkingOutput = OutputPathUtilities.prepareWorkingOutput(
                for: sourceURL,
                destinationURL: destinationURL
            )

            return PreparedSourceConversion(
                sourceURL: sourceURL,
                sourceID: sourceID,
                destinationURL: destinationURL,
                workingOutputURL: preparedWorkingOutput.url,
                sourceFingerprint: OutputPathUtilities.fileFingerprint(for: sourceURL),
                workingOutputStrategy: preparedWorkingOutput.strategy
            )
        }

        guard preparedSources.count == sourceURLs.count else {
            stopAccessingBatchDirectory()
            return nil
        }

        return PreparedBatchConversionContext(
            preparedSources: preparedSources,
            outputDirectoryURL: batchAccess.batchDirectoryURL ?? selectedDestinations.outputDirectoryURL,
            stopAccessingBatchDirectory: stopAccessingBatchDirectory
        )
    }

    static func cleanupWorkingOutputIfNeeded(_ workingOutputURL: URL) {
        if FileManager.default.fileExists(atPath: workingOutputURL.path) {
            try? FileManager.default.removeItem(at: workingOutputURL)
        }
    }

    static func savePreparedConvertedOutput(
        from sourceURL: URL,
        preparedSource: PreparedSourceConversion
    ) throws -> URL {
        let destinationDirectoryURL = preparedSource.destinationURL.deletingLastPathComponent()

        return try SecurityScopedResourceAccess.withAccess(to: preparedSource.destinationURL) {
            try SecurityScopedResourceAccess.withAccess(to: destinationDirectoryURL) {
                try OutputPathUtilities.commitPreparedOutput(
                    from: sourceURL,
                    to: preparedSource.destinationURL,
                    strategy: preparedSource.workingOutputStrategy
                )
            }
        }
    }
}
