import Foundation
import AVFoundation

struct VideoOutputSettings {
    let videoCodecCandidates: [String]
    let useHEVCTag: Bool
    let resolution: (width: Int, height: Int)?
    let frameRate: Int?
    let videoBitRateKbps: Int?
    let audioCodec: String
    let audioChannels: Int?
    let sampleRate: Int
    let audioBitRateKbps: Int?
}

enum VideoConversionEngine {
    typealias ProgressHandler = @Sendable (Double) async -> Void

    static func sandboxOutputDirectory(bundleIdentifier: String?) throws -> URL {
        let appSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let identifier = bundleIdentifier ?? "MyConverter"
        let outputDirectory = appSupportDirectory
            .appendingPathComponent(identifier, isDirectory: true)
            .appendingPathComponent("Converted", isDirectory: true)

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return outputDirectory
    }

    static func uniqueOutputURL(for sourceURL: URL, in outputDirectory: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var candidate = outputDirectory.appendingPathComponent("\(baseName).mp4")
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputDirectory.appendingPathComponent("\(baseName)_converted_\(index).mp4")
            index += 1
        }
        return candidate
    }

    static func temporaryOutputURL(for sourceURL: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)_working_\(UUID().uuidString).mp4")
    }

    static func saveConvertedOutput(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        if sourceURL.path == destinationURL.path {
            return destinationURL
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                try? FileManager.default.removeItem(at: sourceURL)
                return destinationURL
            } catch {
                throw ConversionError.outputSaveFailed(destinationURL.path, error.localizedDescription)
            }
        }
    }

    static func convertToMP4(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        #if os(macOS)
        if let converted = try await attemptFFmpegConversion(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        ) {
            return converted
        }
        #endif

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetReadable(asset)
        } catch {
            if isUnsupportedMediaFormatError(error) {
                #if os(macOS)
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
                #endif
            }
            throw error
        }

        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let preferredPresets = [
            AVAssetExportPresetPassthrough,
            AVAssetExportPresetHighestQuality,
            AVAssetExportPresetMediumQuality,
            AVAssetExportPresetLowQuality
        ]
        let candidatePresets = preferredPresets.filter { compatiblePresets.contains($0) }

        guard !candidatePresets.isEmpty else {
            #if os(macOS)
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
            #else
            throw ConversionError.noCompatiblePreset(compatiblePresets)
            #endif
        }

        var lastError: Error?
        for preset in candidatePresets {
            guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
                lastError = ConversionError.cannotCreateExportSession(preset)
                continue
            }

            guard session.supportedFileTypes.contains(.mp4) else {
                lastError = ConversionError.unsupportedOutputType
                continue
            }

            session.outputURL = outputURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true

            let progressTask = Task {
                while !Task.isCancelled {
                    let status = session.status
                    if status != .waiting && status != .exporting {
                        break
                    }
                    await onProgress(Double(session.progress))
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
            }

            do {
                try await export(session, preset: preset)
                progressTask.cancel()
                if session.status == .completed && FileManager.default.fileExists(atPath: outputURL.path) {
                    await onProgress(1)
                    return outputURL
                }
                lastError = ConversionError.exportFailed(status: session.status, underlying: session.error, preset: preset)
            } catch {
                progressTask.cancel()
                lastError = error
                if isUnsupportedMediaFormatError(error) {
                    break
                }
            }
        }

        #if os(macOS)
        if let lastError, shouldFallbackToFFmpeg(after: lastError) {
            if let converted = try await attemptFFmpegConversion(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                onProgress: onProgress
            ) {
                return converted
            }

            if isUnsupportedMediaFormatError(lastError) {
                throw ConversionError.ffmpegUnavailable
            }
        }
        #endif

        throw lastError ?? ConversionError.unsupportedSource
    }

    #if os(macOS)
    private static func attemptFFmpegConversion(
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

    private static func convertWithFFmpegIfAvailable(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> Bool {
        guard let ffmpegPath = findFFmpegPath() else {
            return false
        }

        try await convertMKVToMP4WithFFmpeg(
            ffmpegPath: ffmpegPath,
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        )
        return true
    }

    private static func convertMKVToMP4WithFFmpeg(
        ffmpegPath: String,
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        var lastError: Error?
        for codec in outputSettings.videoCodecCandidates {
            do {
                try await runFFmpeg(
                    ffmpegPath: ffmpegPath,
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings,
                    videoCodec: codec,
                    inputDurationSeconds: inputDurationSeconds,
                    onProgress: onProgress
                )
                return
            } catch {
                lastError = error
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try? FileManager.default.removeItem(at: outputURL)
                }
            }
        }

        throw lastError ?? ConversionError.ffmpegFailed(-1, "No supported video encoder found.")
    }

    private static func runFFmpeg(
        ffmpegPath: String,
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        videoCodec: String,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws {
        let args = buildFFmpegArguments(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            videoCodec: videoCodec
        )

        await onProgress(0)

        var effectiveDuration = inputDurationSeconds
        let result = try await runCommand(path: ffmpegPath, arguments: args) { line in
            if effectiveDuration == nil {
                effectiveDuration = parseFFmpegDurationSeconds(from: line)
            }

            if line == "progress=end" {
                Task {
                    await onProgress(1)
                }
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
            Task {
                await onProgress(ratio)
            }
        }

        guard result.terminationStatus == 0 else {
            throw ConversionError.ffmpegFailed(
                result.terminationStatus,
                "[\(videoCodec)] \(result.output)"
            )
        }

        await onProgress(1)
    }

    private static func buildFFmpegArguments(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        videoCodec: String
    ) -> [String] {
        var args = [
            "-y",
            "-progress", "pipe:1",
            "-nostats",
            "-i", inputURL.path,
            "-c:v", videoCodec
        ]

        appendVideoEncodingArguments(&args, outputSettings: outputSettings)
        appendAudioEncodingArguments(&args, outputSettings: outputSettings)

        args.append(contentsOf: [
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            outputURL.path
        ])

        return args
    }

    private static func appendVideoEncodingArguments(
        _ args: inout [String],
        outputSettings: VideoOutputSettings
    ) {
        if let dimensions = outputSettings.resolution {
            args.append(contentsOf: ["-vf", "scale=\(dimensions.width):\(dimensions.height)"])
        }

        if let fps = outputSettings.frameRate {
            args.append(contentsOf: ["-r", "\(fps)"])
        }

        if let videoBitRate = outputSettings.videoBitRateKbps {
            args.append(contentsOf: ["-b:v", "\(videoBitRate)k"])
        }

        if outputSettings.useHEVCTag {
            args.append(contentsOf: ["-tag:v", "hvc1"])
        }
    }

    private static func appendAudioEncodingArguments(
        _ args: inout [String],
        outputSettings: VideoOutputSettings
    ) {
        args.append(contentsOf: [
            "-c:a", outputSettings.audioCodec,
            "-ar", "\(outputSettings.sampleRate)"
        ])

        if let channels = outputSettings.audioChannels {
            args.append(contentsOf: ["-ac", "\(channels)"])
        }

        if let audioBitRate = outputSettings.audioBitRateKbps {
            args.append(contentsOf: ["-b:a", "\(audioBitRate)k"])
        }
    }

    private static func findFFmpegPath() -> String? {
        var candidates: [String] = []

        if let bundled = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            candidates.append(bundled)
        }
        if let resourcePath = Bundle.main.resourceURL?.path {
            candidates.append("\(resourcePath)/ffmpeg")
            candidates.append("\(resourcePath)/bin/ffmpeg")
        }
        if let executableDir = Bundle.main.executableURL?.deletingLastPathComponent().path {
            candidates.append("\(executableDir)/ffmpeg")
            candidates.append("\(executableDir)/bin/ffmpeg")
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ])
        if let fixed = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixed
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for directory in path.split(separator: ":") {
                let candidate = "\(directory)/ffmpeg"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
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

    private static func consumeCompleteLines(from buffer: inout Data) -> [String] {
        var lines: [String] = []
        let newline = Data([0x0A])

        while let range = buffer.range(of: newline) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            let text = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                lines.append(text)
            }
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
        }

        return lines
    }

    private static func runCommand(
        path: String,
        arguments: [String],
        outputLineHandler: ((String) -> Void)? = nil
    ) async throws -> (terminationStatus: Int32, output: String) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int32, String), Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            let outputHandle = outputPipe.fileHandleForReading
            let syncQueue = DispatchQueue(label: "myconverter.runcommand.output")
            var accumulated = Data()
            var lineBuffer = Data()

            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }

                syncQueue.async {
                    accumulated.append(data)
                    lineBuffer.append(data)
                    let lines = Self.consumeCompleteLines(from: &lineBuffer)
                    guard let outputLineHandler else { return }
                    for line in lines {
                        outputLineHandler(line)
                    }
                }
            }

            process.terminationHandler = { proc in
                outputHandle.readabilityHandler = nil
                let trailingData = outputHandle.readDataToEndOfFile()

                syncQueue.async {
                    if !trailingData.isEmpty {
                        accumulated.append(trailingData)
                        lineBuffer.append(trailingData)
                    }

                    let lines = Self.consumeCompleteLines(from: &lineBuffer)
                    if let outputLineHandler {
                        for line in lines {
                            outputLineHandler(line)
                        }

                        if !lineBuffer.isEmpty,
                           let trailingLine = String(data: lineBuffer, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !trailingLine.isEmpty {
                            outputLineHandler(trailingLine)
                        }
                    }

                    let output = String(data: accumulated, encoding: .utf8) ?? ""
                    continuation.resume(returning: (proc.terminationStatus, output))
                }
            }

            do {
                try process.run()
            } catch {
                outputHandle.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
    #endif

    private static func shouldFallbackToFFmpeg(after error: Error) -> Bool {
        if let conversionError = error as? ConversionError {
            switch conversionError {
            case .invalidCustomVideoBitRate,
                    .exportCancelled,
                    .ffmpegUnavailable,
                    .ffmpegFailed:
                return false
            default:
                return true
            }
        }

        if isUnsupportedMediaFormatError(error) {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == AVFoundationErrorDomain || nsError.domain == NSOSStatusErrorDomain {
            return true
        }

        if error is AVError {
            return true
        }

        return false
    }

    private static func isUnsupportedMediaFormatError(_ error: Error) -> Bool {
        if let conversionError = error as? ConversionError {
            if case let .exportFailed(_, underlying: underlying, _) = conversionError {
                if let underlying {
                    return isUnsupportedMediaFormatError(underlying)
                }
            }
            if case .unreadableAsset = conversionError {
                return true
            }
            if case .ffmpegFailed = conversionError {
                return false
            }
            return false
        }

        if let avError = error as? AVError {
            return avError.code == .fileFormatNotRecognized ||
                avError.code == .decoderNotFound
        }

        let nsError = error as NSError
        if nsError.domain == AVFoundationErrorDomain {
            if nsError.code == -11828 ||
                nsError.code == AVError.fileFormatNotRecognized.rawValue ||
                nsError.code == AVError.decoderNotFound.rawValue {
                return true
            }

            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                return isUnsupportedMediaFormatError(underlying)
            }

            if let dependencies = nsError.userInfo["AVErrorFailedDependenciesKey"] as? [Any],
               dependencies.contains(where: { item in
                guard let depError = item as? Error else { return false }
                return isUnsupportedMediaFormatError(depError)
            }) {
                return true
            }
        }

        if nsError.domain == NSOSStatusErrorDomain && (nsError.code == -12847 || nsError.code == -12894) {
            return true
        }

        return false
    }

    private static func ensureAssetReadable(_ asset: AVURLAsset) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let keys = ["tracks", "playable", "duration"]
            asset.loadValuesAsynchronously(forKeys: keys) {
                for key in keys {
                    var keyError: NSError?
                    let status = asset.statusOfValue(forKey: key, error: &keyError)
                    if status == .failed || status == .cancelled {
                        continuation.resume(
                            throwing: keyError ?? ConversionError.unreadableAsset
                        )
                        return
                    }
                    if status != .loaded {
                        continuation.resume(
                            throwing: ConversionError.unreadableAsset
                        )
                        return
                    }
                }

                let hasMediaTrack = !(asset.tracks(withMediaType: .video).isEmpty &&
                                      asset.tracks(withMediaType: .audio).isEmpty)
                if !hasMediaTrack {
                    continuation.resume(throwing: ConversionError.noTracksFound)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private static func export(_ session: AVAssetExportSession, preset: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume(returning: ())
                case .cancelled:
                    continuation.resume(throwing: ConversionError.exportCancelled)
                default:
                    continuation.resume(
                        throwing: ConversionError.exportFailed(
                            status: session.status,
                            underlying: session.error,
                            preset: preset
                        )
                    )
                }
            }
        }
    }
}

enum ConversionError: LocalizedError {
    case unsupportedSource
    case unreadableAsset
    case noTracksFound
    case invalidCustomVideoBitRate(String)
    case noCompatiblePreset([String])
    case cannotCreateExportSession(String)
    case unsupportedOutputType
    case exportCancelled
    case exportFailed(status: AVAssetExportSession.Status, underlying: Error?, preset: String)
    case ffmpegUnavailable
    case ffmpegFailed(Int32, String)
    case outputSaveFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "Failed to read input files."
        case .unreadableAsset:
            return "Could not parse MKV file."
        case .noTracksFound:
            return "No video/audio tracks found."
        case .invalidCustomVideoBitRate:
            return "Custom Video Bit Rate must be an integer greater than 1 (Kbps)."
        case .noCompatiblePreset:
            return "No compatible export preset found in AVFoundation."
        case .cannotCreateExportSession:
            return "Could not create conversion session."
        case .unsupportedOutputType:
            return "MP4 output is not supported on this device."
        case .exportCancelled:
            return "Conversion cancelled."
        case .ffmpegUnavailable:
            return "Cannot open this MKV with AVFoundation. ffmpeg not found."
        case .ffmpegFailed(_, let output):
            if output.localizedCaseInsensitiveContains("operation not permitted") ||
                output.localizedCaseInsensitiveContains("permission denied") {
                return "Conversion failed due to file permission issues. Please check input file permissions."
            }
            return "FFmpeg conversion failed."
        case .outputSaveFailed:
            return "Failed to save output file. Please check app storage permissions."
        case .exportFailed:
            return "AVAssetExportSession conversion failed."
        }
    }

    var debugInfo: String {
        switch self {
        case .noCompatiblePreset(let presets):
            return "Supported presets: \(presets.joined(separator: ", "))"
        case .cannotCreateExportSession(let preset):
            return "Failed to create session with preset: \(preset)"
        case .unsupportedOutputType:
            return "Does not allow .mp4 as outputFileType."
        case .exportFailed(let status, let underlying, let preset):
            if let underlying {
                return "Preset: \(preset), Status: \(status), Detail: \(underlying.localizedDescription)"
            }
            return "Preset: \(preset), Status: \(status)"
        case .exportCancelled:
            return "Status: cancelled"
        case .ffmpegUnavailable:
            return "brew install ffmpeg or include ffmpeg in app bundle."
        case .ffmpegFailed(let code, let output):
            return "FFmpeg exit code: \(code). Detail: \(output)"
        case .outputSaveFailed(let path, let reason):
            return "Save path: \(path), Detail: \(reason)"
        case .invalidCustomVideoBitRate(let value):
            return "Input value: \(value)"
        case .unreadableAsset:
            return "Failed to read MKV parser (Codec might be unsupported)."
        case .unsupportedSource:
            return "Use unsupported MKV codec/container."
        case .noTracksFound:
            return "Video/Audio track not detected."
        }
    }
}
