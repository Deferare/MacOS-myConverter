import Foundation

extension ContentViewModel {
    func withSourceSecurityScope<T>(
        for sourceURL: URL,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await SecurityScopedResourceAccess.withAccess(to: sourceURL, operation: operation)
    }

    func runBatchConversionLoop(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        destinationErrorCode: Int,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onBatchIndexChanged: @escaping (Int) -> Void
    ) async throws -> [String] {
        var skippedEntries: [String] = []
        let totalCount = max(sourceURLs.count, 1)

        for (index, currentSourceURL) in sourceURLs.enumerated() {
            try Task.checkCancellation()
            onBatchIndexChanged(index + 1)

            let shouldSkipSource = try await withSourceSecurityScope(for: currentSourceURL) {
                if let validationMessage = await validate(currentSourceURL) {
                    skippedEntries.append("\(currentSourceURL.lastPathComponent): \(validationMessage)")
                    onSourceProcessed(currentSourceURL)
                    return true
                }

                let destinationURL = try BatchConversionSupport.destinationURL(
                    for: currentSourceURL,
                    in: destinationURLsBySourceID,
                    errorCode: destinationErrorCode
                )

                let workingOutputURL = makeWorkingOutputURL(currentSourceURL)
                defer { BatchConversionSupport.cleanupWorkingOutputIfNeeded(workingOutputURL) }

                let output = try await runConversion(
                    currentSourceURL,
                    workingOutputURL,
                    index,
                    totalCount
                )
                try Task.checkCancellation()

                let savedURL = try BatchConversionSupport.saveConvertedOutput(from: output, to: destinationURL)
                onSavedOutput(savedURL)
                onSourceProcessed(currentSourceURL)
                return false
            }

            if shouldSkipSource {
                continue
            }
        }

        return skippedEntries
    }
}
