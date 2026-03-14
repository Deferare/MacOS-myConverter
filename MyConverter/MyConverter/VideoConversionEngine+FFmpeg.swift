import Foundation

extension VideoConversionEngine {
    nonisolated static func isFFmpegAvailable() -> Bool {
        ffmpegRuntime() != nil
    }

    static func convertAudio(
        inputURL: URL,
        outputURL: URL,
        outputSettings: AudioOutputSettings,
        inputDurationSeconds: Double?,
        ffmpegContext: FFmpegExecutionContext? = nil,
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider(),
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)

        guard let ffmpegContext = ffmpegContext ?? makeFFmpegExecutionContext(using: runtimeProvider) else {
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
            runtime: ffmpegContext.runtime,
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
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider(),
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL? {
        let didConvert = try await convertWithFFmpegIfAvailable(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            ffmpegContext: ffmpegContext,
            runtimeProvider: runtimeProvider,
            stagedInputLease: stagedInputLease,
            onProgress: onProgress
        )
        return didConvert ? outputURL : nil
    }

    nonisolated static func makeFFmpegExecutionContext(
        using runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) -> FFmpegExecutionContext? {
        FFmpegExecutionContextSupport.makeContext(
            using: runtimeProvider,
            inspect: { try inspectFFmpeg(using: $0) }
        )
    }

    static func ffmpegCanReadMappedStream(
        runtime: any FFmpegRuntime,
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
            guard let result = try? await runtime.runCommand(
                arguments: [
                    "-hide_banner",
                    "-loglevel", "error",
                    "-i", stagedInputURL.path
                ] + probeArguments,
                outputLineHandler: nil
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

    static func ffmpegCanReadMappedStream(
        ffmpegPath: String,
        inputURL: URL,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        mapSpecifier: String,
        frameArguments: [String]
    ) async -> Bool {
        await ffmpegCanReadMappedStream(
            runtime: ProcessFFmpegRuntime(path: ffmpegPath),
            inputURL: inputURL,
            stagedInputLease: stagedInputLease,
            mapSpecifier: mapSpecifier,
            frameArguments: frameArguments
        )
    }
}
