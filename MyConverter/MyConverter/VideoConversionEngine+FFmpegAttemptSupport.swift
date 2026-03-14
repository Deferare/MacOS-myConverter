import Foundation

extension VideoConversionEngine {
    static func withStagedFFmpegInput<T>(
        for inputURL: URL,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        operation: (URL) async throws -> T
    ) async throws -> T {
        if let stagedInputLease {
            return try await operation(stagedInputLease.stagedURL)
        }

        return try await FFmpegStagingSupport.withStagedInput(
            for: inputURL,
            makeError: { code, message in
                ConversionError.ffmpegFailed(code, message)
            },
            operation: operation
        )
    }

    static func performFFmpegAttempts(
        codecPairs: [(video: String?, audio: String?)],
        outputURL: URL,
        operation: (String?, String?) async throws -> Void,
        fallbackErrorMessage: String
    ) async throws {
        var lastError: Error?
        for codecPair in codecPairs {
            if let error = try await attemptFFmpegOperation(
                outputURL: outputURL,
                operation: {
                    try await operation(codecPair.video, codecPair.audio)
                }
            ) {
                lastError = error
                continue
            }

            return
        }

        throw lastError ?? ConversionError.ffmpegFailed(-1, fallbackErrorMessage)
    }

    static func attemptFFmpegOperation(
        outputURL: URL,
        operation: () async throws -> Void
    ) async throws -> Error? {
        try Task.checkCancellation()

        do {
            try await operation()
            return nil
        } catch {
            try rethrowIfExportCancelled(error)
            try? OutputPathUtilities.removeFileIfExists(at: outputURL)
            return error
        }
    }
}
