import Foundation

extension ContentViewModel {
    func withSourceSecurityScope<T>(
        for sourceURL: URL,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await SecurityScopedResourceAccess.withAccess(to: sourceURL, operation: operation)
    }

    func runBatchConversionLoop(
        preparedSources: [PreparedSourceConversion],
        batchEnvironment: BatchExecutionEnvironment,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping (PreparedSourceConversion, BatchExecutionEnvironment, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL, URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onBatchIndexChanged: @escaping (Int) -> Void
    ) async throws -> [String] {
        var skippedEntries: [String] = []
        let totalCount = max(preparedSources.count, 1)

        for (index, preparedSource) in preparedSources.enumerated() {
            try Task.checkCancellation()
            onBatchIndexChanged(index + 1)

            let shouldSkipSource = try await withSourceSecurityScope(for: preparedSource.sourceURL) {
                if let validationMessage = await validate(preparedSource, batchEnvironment) {
                    skippedEntries.append("\(preparedSource.sourceURL.lastPathComponent): \(validationMessage)")
                    onSourceProcessed(preparedSource.sourceURL)
                    return true
                }

                defer {
                    BatchConversionSupport.cleanupWorkingOutputIfNeeded(
                        preparedSource.workingOutputURL
                    )
                }

                let output = try await runConversion(
                    preparedSource,
                    batchEnvironment,
                    index,
                    totalCount
                )
                try Task.checkCancellation()

                let savedURL = try BatchConversionSupport.savePreparedConvertedOutput(
                    from: output,
                    preparedSource: preparedSource
                )
                onSavedOutput(preparedSource.sourceURL, savedURL)
                onSourceProcessed(preparedSource.sourceURL)
                return false
            }

            if shouldSkipSource {
                continue
            }
        }

        return skippedEntries
    }
}
