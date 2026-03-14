import Foundation

extension VideoConversionEngine {
    static func runFFmpeg(
        runtime: any FFmpegRuntime,
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        videoCodec: String?,
        audioCodec: String?,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws {
        let args = FFmpegArgumentBuilder.makeVideoArguments(
            inputURL: inputURL,
            outputURL: outputURL,
            settings: outputSettings,
            videoCodec: videoCodec,
            audioCodec: audioCodec
        )

        let result = try await runFFmpegCommandWithProgress(
            runtime: runtime,
            arguments: args,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        )

        guard result.terminationStatus == 0 else {
            let videoCodecLabel = videoCodec ?? "auto"
            let audioCodecLabel = audioCodec ?? "auto"
            throw ConversionError.ffmpegFailed(
                result.terminationStatus,
                "[v:\(videoCodecLabel) a:\(audioCodecLabel)] \(result.output)"
            )
        }

        await onProgress(1)
    }

    static func runFFmpeg(
        ffmpegPath: String,
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        videoCodec: String?,
        audioCodec: String?,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws {
        try await runFFmpeg(
            runtime: ProcessFFmpegRuntime(path: ffmpegPath),
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        )
    }

    static func runAudioFFmpeg(
        runtime: any FFmpegRuntime,
        inputURL: URL,
        outputURL: URL,
        outputSettings: AudioOutputSettings,
        audioCodec: String?,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws {
        let args = FFmpegArgumentBuilder.makeAudioArguments(
            inputURL: inputURL,
            outputURL: outputURL,
            settings: outputSettings,
            audioCodec: audioCodec
        )

        let result = try await runFFmpegCommandWithProgress(
            runtime: runtime,
            arguments: args,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        )

        guard result.terminationStatus == 0 else {
            let audioCodecLabel = audioCodec ?? "auto"
            throw ConversionError.ffmpegFailed(
                result.terminationStatus,
                "[a:\(audioCodecLabel)] \(result.output)"
            )
        }

        await onProgress(1)
    }

    static func runAudioFFmpeg(
        ffmpegPath: String,
        inputURL: URL,
        outputURL: URL,
        outputSettings: AudioOutputSettings,
        audioCodec: String?,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws {
        try await runAudioFFmpeg(
            runtime: ProcessFFmpegRuntime(path: ffmpegPath),
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            audioCodec: audioCodec,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        )
    }
}
