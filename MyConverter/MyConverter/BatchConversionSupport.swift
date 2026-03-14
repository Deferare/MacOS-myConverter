import Foundation

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

    nonisolated static func prepareContext(
        sourceURLs: [URL],
        fileExtension: String,
        outputDirectoryURL: URL,
        outputDirectoryAccessURL: URL? = nil
    ) -> PreparedBatchConversionContext? {
        var destinationURLsBySourceID: [String: URL] = [:]
        var allocator = OutputPathUtilities.ReservedOutputAllocator.preloaded(for: outputDirectoryURL)
        for sourceURL in sourceURLs {
            let destinationURL = allocator.reserveUniqueOutputURL(
                forBaseName: OutputPathUtilities.sourceBaseName(for: sourceURL, fallback: "output"),
                fileExtension: fileExtension
            )
            destinationURLsBySourceID[ContentViewModelSupport.sourceIdentifier(for: sourceURL)] =
                destinationURL
        }

        guard let batchAccess = prepareBatchDirectoryAccess(
            sourceURLs: sourceURLs,
            destinationURLsBySourceID: destinationURLsBySourceID,
            outputDirectoryAccessURL: outputDirectoryAccessURL
        ) else {
            return nil
        }

        let stopAccessingBatchDirectory: @Sendable () -> Void = {
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
                destinationDirectoryAccessURL: batchAccess.batchDirectoryURL ?? outputDirectoryURL,
                workingOutputURL: preparedWorkingOutput.url,
                workingOutputStrategy: preparedWorkingOutput.strategy
            )
        }

        guard preparedSources.count == sourceURLs.count else {
            stopAccessingBatchDirectory()
            return nil
        }

        return PreparedBatchConversionContext(
            preparedSources: preparedSources,
            outputDirectoryURL: batchAccess.batchDirectoryURL ?? outputDirectoryURL,
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
        return try SecurityScopedResourceAccess.withAccess(to: preparedSource.destinationDirectoryAccessURL) {
            try OutputPathUtilities.commitPreparedOutput(
                from: sourceURL,
                to: preparedSource.destinationURL,
                strategy: preparedSource.workingOutputStrategy
            )
        }
    }
}
