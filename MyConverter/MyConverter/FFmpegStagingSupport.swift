import Foundation

enum FFmpegStagingSupport {
    nonisolated static func stageInputURL(
        for inputURL: URL,
        makeError: (Int32, String) -> Error
    ) throws -> URL {
        do {
            return try OutputPathUtilities.stageInputURL(for: inputURL)
        } catch let stagingError as OutputPathUtilities.StagedInputError {
            switch stagingError {
            case .stagingDirectoryCreationFailed(let path, let message):
                throw makeError(
                    -1,
                    "Failed to prepare ffmpeg staging directory (\(path)): \(message)"
                )
            case .stagingCopyFailed(let sourcePath, let destinationPath, let message):
                throw makeError(
                    -1,
                    "Failed to stage input file for ffmpeg. Source: \(sourcePath), Destination: \(destinationPath), Detail: \(message)"
                )
            }
        } catch {
            throw makeError(
                -1,
                "Failed to stage input file for ffmpeg: \(error.localizedDescription)"
            )
        }
    }

    nonisolated static func withStagedInput<T>(
        for inputURL: URL,
        makeError: (Int32, String) -> Error,
        operation: (URL) async throws -> T
    ) async throws -> T {
        let token = PerformanceSignpost.begin("FFmpegStageInput", message: inputURL.lastPathComponent)
        let stagedInputURL: URL
        do {
            stagedInputURL = try stageInputURL(for: inputURL, makeError: makeError)
            PerformanceSignpost.end("FFmpegStageInput", token: token, message: inputURL.lastPathComponent)
        } catch {
            PerformanceSignpost.end("FFmpegStageInput", token: token, message: "failed")
            throw error
        }
        defer {
            try? OutputPathUtilities.removeFileIfExists(at: stagedInputURL)
        }
        return try await operation(stagedInputURL)
    }
}
