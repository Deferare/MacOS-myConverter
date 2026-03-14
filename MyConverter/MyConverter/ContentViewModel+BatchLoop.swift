import Foundation

extension ContentViewModel {
    enum PreparedSourceExecutionResult: Sendable {
        case saved(URL)
        case skipped(String)
    }

    func withSourceSecurityScope<T>(
        for sourceURL: URL,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await SecurityScopedResourceAccess.withAccess(to: sourceURL, operation: operation)
    }

    func processPreparedSourceConversion(
        _ preparedSource: PreparedSourceConversion,
        batchEnvironment: BatchExecutionEnvironment,
        validate: @escaping (PreparedSourceConversion, BatchExecutionEnvironment) async -> String?,
        runConversion: @escaping () async throws -> URL
    ) async throws -> PreparedSourceExecutionResult {
        try await withSourceSecurityScope(for: preparedSource.sourceURL) {
            if let validationMessage = await validate(preparedSource, batchEnvironment) {
                return .skipped(
                    "\(preparedSource.sourceURL.lastPathComponent): \(validationMessage)"
                )
            }

            defer {
                BatchConversionSupport.cleanupWorkingOutputIfNeeded(
                    preparedSource.workingOutputURL
                )
            }

            let output = try await runConversion()
            try Task.checkCancellation()

            let savedURL = try BatchConversionSupport.savePreparedConvertedOutput(
                from: output,
                preparedSource: preparedSource
            )
            return .saved(savedURL)
        }
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

            let result = try await processPreparedSourceConversion(
                preparedSource,
                batchEnvironment: batchEnvironment,
                validate: validate,
                runConversion: {
                    try await runConversion(
                        preparedSource,
                        batchEnvironment,
                        index,
                        totalCount
                    )
                }
            )

            switch result {
            case let .skipped(skippedEntry):
                skippedEntries.append(skippedEntry)
            case let .saved(savedURL):
                onSavedOutput(preparedSource.sourceURL, savedURL)
            }
            onSourceProcessed(preparedSource.sourceURL)
        }

        return skippedEntries
    }
}
