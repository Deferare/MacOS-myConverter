import Foundation

extension VideoConversionEngine {
    static func convertWithFFmpegIfAvailable(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        ffmpegContext: FFmpegExecutionContext? = nil,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        onProgress: @escaping ProgressHandler
    ) async throws -> Bool {
        guard let ffmpegContext = ffmpegContext ?? makeFFmpegExecutionContext() else {
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
            ffmpegPath: ffmpegContext.ffmpegPath,
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
        ffmpegPath: String,
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
                        ffmpegPath: ffmpegPath,
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
        ffmpegPath: String,
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
                        ffmpegPath: ffmpegPath,
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

    private static func codecCandidates(
        availableCodecs: [String],
        allowAutomatic: Bool
    ) -> [String?] {
        if availableCodecs.isEmpty {
            return allowAutomatic ? [nil] : []
        }
        return availableCodecs.map(Optional.init)
    }

    private static func withStagedFFmpegInput<T>(
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

    private static func codecPairs(
        videoCodecs: [String?],
        audioCodecs: [String?]
    ) -> [(video: String?, audio: String?)] {
        var pairs: [(video: String?, audio: String?)] = []
        pairs.reserveCapacity(videoCodecs.count * audioCodecs.count)

        for videoCodec in videoCodecs {
            for audioCodec in audioCodecs {
                pairs.append((video: videoCodec, audio: audioCodec))
            }
        }

        return pairs
    }

    private static func audioCodecPairs(_ audioCodecs: [String?]) -> [(video: String?, audio: String?)] {
        audioCodecs.map { (video: nil, audio: $0) }
    }

    private static func performFFmpegAttempts(
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
    private static func attemptFFmpegOperation(
        outputURL: URL,
        operation: () async throws -> Void
    ) async throws -> Error? {
        try Task.checkCancellation()

        do {
            try await operation()
            return nil
        } catch is CancellationError {
            throw ConversionError.exportCancelled
        } catch ConversionError.exportCancelled {
            throw ConversionError.exportCancelled
        } catch {
            try? OutputPathUtilities.removeFileIfExists(at: outputURL)
            return error
        }
    }
}
