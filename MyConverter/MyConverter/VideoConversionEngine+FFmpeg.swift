import Foundation

extension VideoConversionEngine {
    static func convertAudio(
        inputURL: URL,
        outputURL: URL,
        outputSettings: AudioOutputSettings,
        inputDurationSeconds: Double?,
        ffmpegContext: FFmpegExecutionContext? = nil,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)

        guard let ffmpegContext = ffmpegContext ?? makeFFmpegExecutionContext() else {
            throw ConversionError.ffmpegUnavailable
        }

        guard isFFmpegAudioFormatSupported(
            outputSettings.containerFormat,
            introspection: ffmpegContext.introspection
        ) else {
            throw ConversionError.ffmpegFailed(-1, "Selected audio container is not supported by this ffmpeg build.")
        }

        try await convertAudioWithFFmpeg(
            introspection: ffmpegContext.introspection,
            ffmpegPath: ffmpegContext.ffmpegPath,
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        )
        return outputURL
    }

    static func attemptFFmpegConversionOrThrowUnavailable(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        ffmpegContext: FFmpegExecutionContext? = nil,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        if let converted = try await attemptFFmpegConversion(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            ffmpegContext: ffmpegContext,
            stagedInputLease: stagedInputLease,
            onProgress: onProgress
        ) {
            return converted
        }
        throw ConversionError.ffmpegUnavailable
    }

    static func attemptFFmpegConversion(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        ffmpegContext: FFmpegExecutionContext? = nil,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL? {
        let didConvert = try await convertWithFFmpegIfAvailable(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            ffmpegContext: ffmpegContext,
            stagedInputLease: stagedInputLease,
            onProgress: onProgress
        )
        return didConvert ? outputURL : nil
    }

    static func makeFFmpegExecutionContext() -> FFmpegExecutionContext? {
        guard let ffmpegPath = FFmpegBinaryLocator.findPath(),
              let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
            return nil
        }

        return FFmpegExecutionContext(
            ffmpegPath: ffmpegPath,
            introspection: introspection
        )
    }

    static func ffmpegCanReadMappedStream(
        ffmpegPath: String,
        inputURL: URL,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        mapSpecifier: String,
        frameArguments: [String]
    ) async -> Bool {
        let probeArguments = [
            "-map", mapSpecifier
        ] + frameArguments + [
            "-f", "null",
            "-"
        ]

        let runProbe: (URL) async -> Bool = { stagedInputURL in
            guard let result = try? await ProcessCommandRunner.runCommand(
                path: ffmpegPath,
                arguments: [
                    "-hide_banner",
                    "-loglevel", "error",
                    "-i", stagedInputURL.path
                ] + probeArguments
            ) else {
                return false
            }

            return result.terminationStatus == 0
        }

        if let stagedInputLease {
            return await runProbe(stagedInputLease.stagedURL)
        }

        return (try? await FFmpegStagingSupport.withStagedInput(
            for: inputURL,
            makeError: { code, message in
                ConversionError.ffmpegFailed(code, message)
            },
            operation: runProbe
        )) ?? false
    }
}
