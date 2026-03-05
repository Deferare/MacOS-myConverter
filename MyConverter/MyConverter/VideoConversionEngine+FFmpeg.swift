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

    private static func convertWithFFmpegIfAvailable(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> Bool {
        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return false
        }

        guard let introspection = try? inspectFFmpeg(at: ffmpegPath),
              isFFmpegFormatSupported(outputSettings.containerFormat, introspection: introspection) else {
            return false
        }

        try await convertWithFFmpeg(
            introspection: introspection,
            ffmpegPath: ffmpegPath,
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        )
        return true
    }

    private static func convertWithFFmpeg(
        introspection: FFmpegIntrospection,
        ffmpegPath: String,
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)
        try await withStagedFFmpegInput(for: inputURL) { stagedInputURL in
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

    private static func convertAudioWithFFmpeg(
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
        operation: (URL) async throws -> T
    ) async throws -> T {
        try await FFmpegStagingSupport.withStagedInput(
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

    private static func stageInputForFFmpeg(_ inputURL: URL) throws -> URL {
        try FFmpegStagingSupport.stageInputURL(for: inputURL) { code, message in
            ConversionError.ffmpegFailed(code, message)
        }
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

    private static func runFFmpeg(
        ffmpegPath: String,
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
            ffmpegPath: ffmpegPath,
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

    private static func runAudioFFmpeg(
        ffmpegPath: String,
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
            ffmpegPath: ffmpegPath,
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

    private static func runFFmpegCommandWithProgress(
        ffmpegPath: String,
        arguments: [String],
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> (terminationStatus: Int32, output: String) {
        try Task.checkCancellation()
        await onProgress(0)

        var effectiveDuration = inputDurationSeconds
        var lastReportedProgress = 0.0
        var lastReportTime: UInt64 = DispatchTime.now().uptimeNanoseconds
        let result = try await ProcessCommandRunner.runCommand(path: ffmpegPath, arguments: arguments) { line in
            if effectiveDuration == nil {
                effectiveDuration = parseFFmpegDurationSeconds(from: line)
            }

            if line == "progress=end" {
                enqueueProgressUpdate(
                    progress: 1,
                    lastReportedProgress: &lastReportedProgress,
                    lastReportTime: &lastReportTime,
                    onProgress: onProgress
                )
                return
            }

            guard
                let outTimeSeconds = parseFFmpegOutTimeSeconds(from: line),
                let duration = effectiveDuration,
                duration > 0
            else {
                return
            }

            let ratio = outTimeSeconds / duration
            enqueueProgressUpdate(
                progress: ratio,
                lastReportedProgress: &lastReportedProgress,
                lastReportTime: &lastReportTime,
                onProgress: onProgress
            )
        }
        try Task.checkCancellation()
        return result
    }

    private static func enqueueProgressUpdate(
        progress: Double,
        lastReportedProgress: inout Double,
        lastReportTime: inout UInt64,
        onProgress: @escaping ProgressHandler
    ) {
        let clamped = min(max(progress, 0), 1)
        if clamped < 1, clamped <= lastReportedProgress {
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let intervalElapsed = now >= lastReportTime + 120_000_000
        let stepAdvanced = clamped - lastReportedProgress >= 0.01
        let shouldEmit = clamped >= 1 || stepAdvanced || intervalElapsed
        guard shouldEmit else { return }

        lastReportedProgress = clamped
        lastReportTime = now
        Task {
            await onProgress(clamped)
        }
    }

    private static func parseFFmpegDurationSeconds(from line: String) -> Double? {
        guard let markerRange = line.range(of: "Duration: ") else { return nil }
        let remaining = line[markerRange.upperBound...]
        guard let commaIndex = remaining.firstIndex(of: ",") else { return nil }
        let timestamp = String(remaining[..<commaIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return parseFFmpegTimestampSeconds(timestamp)
    }

    private static func parseFFmpegOutTimeSeconds(from line: String) -> Double? {
        if line.hasPrefix("out_time=") {
            let value = String(line.dropFirst("out_time=".count))
            return parseFFmpegTimestampSeconds(value)
        }

        if let seconds = parseFFmpegProgressTimeValue(from: line, key: "out_time_us=") {
            return seconds
        }

        if let seconds = parseFFmpegProgressTimeValue(from: line, key: "out_time_ms=") {
            return seconds
        }

        return nil
    }

    private static func parseFFmpegProgressTimeValue(from line: String, key: String) -> Double? {
        guard line.hasPrefix(key) else { return nil }
        let raw = String(line.dropFirst(key.count))
        guard let value = Double(raw) else { return nil }
        return value / 1_000_000
    }

    private static func parseFFmpegTimestampSeconds(_ timestamp: String) -> Double? {
        let normalized = timestamp
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let components = normalized.split(separator: ":")
        guard components.count == 3 else { return nil }
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }
        return (hours * 3600) + (minutes * 60) + seconds
    }
}
