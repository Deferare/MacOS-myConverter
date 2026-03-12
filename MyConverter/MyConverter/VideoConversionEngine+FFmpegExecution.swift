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

    private static func runFFmpegCommandWithProgress(
        runtime: any FFmpegRuntime,
        arguments: [String],
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> FFmpegCommandResult {
        try Task.checkCancellation()
        await onProgress(0)

        let token = PerformanceSignpost.begin("VideoEncode", message: runtime.displayName)
        let progressStateQueue = DispatchQueue(label: "myconverter.ffmpeg.progress.state")
        var effectiveDuration = inputDurationSeconds
        var lastReportedProgress = 0.0
        var lastReportTime: UInt64 = DispatchTime.now().uptimeNanoseconds
        let result: FFmpegCommandResult
        do {
            result = try await runtime.runCommand(arguments: arguments) { line in
                progressStateQueue.sync {
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
            }
            PerformanceSignpost.end("VideoEncode", token: token, message: "ffmpeg")
        } catch {
            PerformanceSignpost.end("VideoEncode", token: token, message: "failed")
            throw error
        }
        try Task.checkCancellation()
        return result
    }

    nonisolated private static func enqueueProgressUpdate(
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
        let intervalElapsed = now >= lastReportTime + 33_000_000
        let stepAdvanced = clamped - lastReportedProgress >= 0.002
        let shouldEmit = clamped >= 1 || stepAdvanced || intervalElapsed
        guard shouldEmit else { return }

        lastReportedProgress = clamped
        lastReportTime = now
        Task {
            await onProgress(clamped)
        }
    }

    nonisolated private static func parseFFmpegDurationSeconds(from line: String) -> Double? {
        guard let markerRange = line.range(of: "Duration: ") else { return nil }
        let remaining = line[markerRange.upperBound...]
        guard let commaIndex = remaining.firstIndex(of: ",") else { return nil }
        let timestamp = String(remaining[..<commaIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return parseFFmpegTimestampSeconds(timestamp)
    }

    nonisolated private static func parseFFmpegOutTimeSeconds(from line: String) -> Double? {
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

    nonisolated private static func parseFFmpegProgressTimeValue(from line: String, key: String) -> Double? {
        guard line.hasPrefix(key) else { return nil }
        let raw = String(line.dropFirst(key.count))
        guard let value = Double(raw) else { return nil }
        return value / 1_000_000
    }

    nonisolated private static func parseFFmpegTimestampSeconds(_ timestamp: String) -> Double? {
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
