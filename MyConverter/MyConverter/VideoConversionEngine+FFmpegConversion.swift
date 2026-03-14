import Foundation

extension VideoConversionEngine {
    static func convertWithFFmpegIfAvailable(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        ffmpegContext: FFmpegExecutionContext? = nil,
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider(),
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        onProgress: @escaping ProgressHandler
    ) async throws -> Bool {
        guard let ffmpegContext = ffmpegContext ?? makeFFmpegExecutionContext(using: runtimeProvider) else {
            return false
        }

        guard isFFmpegFormatSupported(
            outputSettings.containerFormat,
            introspection: ffmpegContext.introspection
        ) else {
            return false
        }

        try await convertWithFFmpeg(
            introspection: ffmpegContext.introspection,
            runtime: ffmpegContext.runtime,
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            stagedInputLease: stagedInputLease,
            onProgress: onProgress
        )
        return true
    }

    static func convertWithFFmpeg(
        introspection: FFmpegIntrospection,
        runtime: any FFmpegRuntime,
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        onProgress: @escaping ProgressHandler
    ) async throws {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)
        try await withStagedFFmpegInput(for: inputURL, stagedInputLease: stagedInputLease) { stagedInputURL in
            let availableVideoCodecs = outputSettings.videoCodecCandidates.filter { introspection.videoEncoders.contains($0) }
            let videoCodecs = codecCandidates(
                availableCodecs: availableVideoCodecs,
                allowAutomatic: outputSettings.containerFormat.allowsFFmpegAutomaticVideoCodec
            )

            let audioCodecs: [String?]
            if !outputSettings.containerFormat.supportsAudioTrack {
                audioCodecs = [nil]
            } else {
                let availableAudioCodecs = outputSettings.audioCodecCandidates.filter { introspection.audioEncoders.contains($0) }
                audioCodecs = codecCandidates(
                    availableCodecs: availableAudioCodecs,
                    allowAutomatic: outputSettings.containerFormat.allowsFFmpegAutomaticAudioCodec
                )
            }

            guard !videoCodecs.isEmpty else {
                throw ConversionError.ffmpegFailed(-1, "No supported video encoder found for selected format.")
            }
            guard !audioCodecs.isEmpty else {
                throw ConversionError.ffmpegFailed(-1, "No supported audio encoder found for selected format.")
            }

            try await performFFmpegAttempts(
                codecPairs: codecPairs(videoCodecs: videoCodecs, audioCodecs: audioCodecs),
                outputURL: outputURL,
                operation: { videoCodec, audioCodec in
                    try await runFFmpeg(
                        runtime: runtime,
                        inputURL: stagedInputURL,
                        outputURL: outputURL,
                        outputSettings: outputSettings,
                        videoCodec: videoCodec,
                        audioCodec: audioCodec,
                        inputDurationSeconds: inputDurationSeconds,
                        onProgress: onProgress
                    )
                },
                fallbackErrorMessage: "No supported video/audio encoder combination found."
            )
        }
    }

    static func convertAudioWithFFmpeg(
        introspection: FFmpegIntrospection,
        runtime: any FFmpegRuntime,
        inputURL: URL,
        outputURL: URL,
        outputSettings: AudioOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)
        try await withStagedFFmpegInput(for: inputURL) { stagedInputURL in
            let availableAudioCodecs = outputSettings.audioCodecCandidates.filter { introspection.audioEncoders.contains($0) }
            let audioCodecs = codecCandidates(
                availableCodecs: availableAudioCodecs,
                allowAutomatic: outputSettings.containerFormat.allowsFFmpegAutomaticAudioCodec
            )

            guard !audioCodecs.isEmpty else {
                throw ConversionError.ffmpegFailed(-1, "No supported audio encoder found for selected format.")
            }

            try await performFFmpegAttempts(
                codecPairs: audioCodecPairs(audioCodecs),
                outputURL: outputURL,
                operation: { _, audioCodec in
                    try await runAudioFFmpeg(
                        runtime: runtime,
                        inputURL: stagedInputURL,
                        outputURL: outputURL,
                        outputSettings: outputSettings,
                        audioCodec: audioCodec,
                        inputDurationSeconds: inputDurationSeconds,
                        onProgress: onProgress
                    )
                },
                fallbackErrorMessage: "No supported audio encoder found for selected format."
            )
        }
    }
}
