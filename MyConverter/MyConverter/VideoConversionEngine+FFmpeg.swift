import Foundation

extension VideoConversionEngine {
    static func convertAudio(
        inputURL: URL,
        outputURL: URL,
        outputSettings: AudioOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            throw ConversionError.ffmpegUnavailable
        }

        let introspection = try inspectFFmpeg(at: ffmpegPath)
        guard isFFmpegAudioFormatSupported(outputSettings.containerFormat, introspection: introspection) else {
            throw ConversionError.ffmpegFailed(-1, "Selected audio container is not supported by this ffmpeg build.")
        }

        try await convertAudioWithFFmpeg(
            introspection: introspection,
            ffmpegPath: ffmpegPath,
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
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        if let converted = try await attemptFFmpegConversion(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
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
        onProgress: @escaping ProgressHandler
    ) async throws -> URL? {
        let didConvert = try await convertWithFFmpegIfAvailable(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        )
        return didConvert ? outputURL : nil
    }

    static func ffmpegCanReadMappedStream(
        ffmpegPath: String,
        inputURL: URL,
        mapSpecifier: String,
        frameArguments: [String]
    ) async -> Bool {
        let stagedInputURL: URL
        do {
            stagedInputURL = try stageInputForFFmpeg(inputURL)
        } catch {
            return false
        }
        defer {
            try? OutputPathUtilities.removeFileIfExists(at: stagedInputURL)
        }

        let arguments = [
            "-hide_banner",
            "-loglevel", "error",
            "-i", stagedInputURL.path,
            "-map", mapSpecifier
        ] + frameArguments + [
            "-f", "null",
            "-"
        ]

        guard let result = try? await ProcessCommandRunner.runCommand(path: ffmpegPath, arguments: arguments) else {
            return false
        }

        return result.terminationStatus == 0
    }
}
