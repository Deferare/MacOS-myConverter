import Foundation
import AVFoundation

struct VideoOutputSettings {
    let containerFormat: VideoFormatOption
    let videoCodecCandidates: [String]
    let useHEVCTag: Bool
    let resolution: (width: Int, height: Int)?
    let frameRate: Int?
    let videoBitRateKbps: Int?
    let audioCodecCandidates: [String]
    let audioChannels: Int?
    let sampleRate: Int?
    let audioBitRateKbps: Int?
}

struct VideoSourceCapabilities {
    let availableOutputFormats: [VideoFormatOption]
    let warningMessage: String?
    let errorMessage: String?
}

enum VideoConversionEngine {
    typealias ProgressHandler = @Sendable (Double) async -> Void
    private static let ffmpegIntrospectionCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.introspection.cache")
    nonisolated(unsafe) private static var ffmpegIntrospectionCache: [String: FFmpegIntrospection] = [:]
    private static let preferredExportPresets = [
        AVAssetExportPresetPassthrough,
        AVAssetExportPresetHighestQuality,
        AVAssetExportPresetMediumQuality,
        AVAssetExportPresetLowQuality
    ]

    static func defaultOutputFormats() -> [VideoFormatOption] {
        let avFormats = VideoFormatOption.avFoundationDefaultFormats

        #if os(macOS)
        guard let ffmpegPath = findFFmpegPath(),
              let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
            return avFormats
        }

        let discovered = ffmpegDiscoveredFormats(from: introspection)
        let candidates = VideoFormatOption.deduplicatedAndSorted(avFormats + VideoFormatOption.ffmpegKnownFormats + discovered)
        let supportedFFmpegFormats = candidates.filter { isFFmpegFormatSupported($0, introspection: introspection) }
        return VideoFormatOption.deduplicatedAndSorted(supportedFFmpegFormats + avFormats)
        #else
        return avFormats
        #endif
    }

    static func availableVideoEncoders(for format: VideoFormatOption) -> [VideoEncoderOption] {
        #if os(macOS)
        guard let ffmpegPath = findFFmpegPath(),
              let introspection = try? inspectFFmpeg(at: ffmpegPath),
              isFFmpegFormatSupported(format, introspection: introspection) else {
            return [.auto]
        }

        let options = VideoEncoderOption.allCases.filter { option in
            option.isCompatible(with: format) &&
                (option.codecCandidates.isEmpty || option.codecCandidates.contains(where: { introspection.videoEncoders.contains($0) }))
        }

        return options.isEmpty ? [.auto] : options
        #else
        return [.auto]
        #endif
    }

    static func availableAudioEncoders(for format: VideoFormatOption) -> [AudioEncoderOption] {
        #if os(macOS)
        guard let ffmpegPath = findFFmpegPath(),
              let introspection = try? inspectFFmpeg(at: ffmpegPath),
              isFFmpegFormatSupported(format, introspection: introspection) else {
            return [.auto]
        }

        let options = AudioEncoderOption.allCases.filter { option in
            option.isCompatible(with: format) &&
                (option.codecCandidates.isEmpty || option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) }))
        }

        return options.isEmpty ? [.auto] : options
        #else
        return [.auto]
        #endif
    }

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

    static func uniqueOutputURL(
        for sourceURL: URL,
        format: VideoFormatOption,
        in outputDirectory: URL
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = format.fileExtension
        var candidate = outputDirectory.appendingPathComponent("\(baseName).\(ext)")
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputDirectory.appendingPathComponent("\(baseName)_converted_\(index).\(ext)")
            index += 1
        }
        return candidate
    }

    static func temporaryOutputURL(for sourceURL: URL, format: VideoFormatOption) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = format.fileExtension
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)_working_\(UUID().uuidString).\(ext)")
    }

    static func saveConvertedOutput(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        if sourceURL.path == destinationURL.path {
            return destinationURL
        }

        try removeFileIfExists(at: destinationURL)

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

    static func isFFmpegAvailable() -> Bool {
        #if os(macOS)
        return findFFmpegPath() != nil
        #else
        return false
        #endif
    }

    static func sourceCapabilities(for inputURL: URL) async -> VideoSourceCapabilities {
        let ffmpegAvailable = isFFmpegAvailable()
        let asset = AVURLAsset(url: inputURL)
        let defaultFormats = defaultOutputFormats()

        do {
            try await ensureAssetReadable(asset)
            let avSupported = await supportedOutputFormatsWithAVFoundation(for: asset)
            if ffmpegAvailable {
                return VideoSourceCapabilities(
                    availableOutputFormats: VideoFormatOption.deduplicatedAndSorted(defaultFormats + avSupported),
                    warningMessage: nil,
                    errorMessage: nil
                )
            }

            if avSupported.isEmpty {
                return VideoSourceCapabilities(
                    availableOutputFormats: [],
                    warningMessage: nil,
                    errorMessage: "No compatible output container is available for this source."
                )
            }

            return VideoSourceCapabilities(
                availableOutputFormats: avSupported,
                warningMessage: nil,
                errorMessage: nil
            )
        } catch {
            if ffmpegAvailable {
                return VideoSourceCapabilities(
                    availableOutputFormats: defaultFormats,
                    warningMessage: nil,
                    errorMessage: nil
                )
            }

            return VideoSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "This source cannot be opened by AVFoundation and ffmpeg is unavailable."
            )
        }
    }

    static func convert(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        try removeFileIfExists(at: outputURL)
        let outputFileType = outputSettings.containerFormat.avFileType

        #if os(macOS)
        if outputFileType == nil {
            return try await attemptFFmpegConversionOrThrowUnavailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                onProgress: onProgress
            )
        }
        #endif

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
                return try await attemptFFmpegConversionOrThrowUnavailable(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: inputDurationSeconds,
                    onProgress: onProgress
                )
                #endif
            }
            throw error
        }

        guard let outputFileType else {
            throw ConversionError.unsupportedOutputType(outputSettings.containerFormat)
        }

        let candidatePresets = await compatibleExportPresets(
            for: asset,
            preferredPresets: preferredExportPresets,
            outputFileType: outputFileType
        )

        guard !candidatePresets.isEmpty else {
            #if os(macOS)
            return try await attemptFFmpegConversionOrThrowUnavailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                onProgress: onProgress
            )
            #else
            throw ConversionError.noCompatiblePreset(preferredExportPresets)
            #endif
        }

        var lastError: Error?
        for preset in candidatePresets {
            guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
                lastError = ConversionError.cannotCreateExportSession(preset)
                continue
            }

            guard session.supportedFileTypes.contains(outputFileType) else {
                lastError = ConversionError.unsupportedOutputType(outputSettings.containerFormat)
                continue
            }

            session.shouldOptimizeForNetworkUse = true

            do {
                try await export(
                    session,
                    to: outputURL,
                    as: outputFileType,
                    preset: preset,
                    onProgress: onProgress
                )
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    return outputURL
                }
                lastError = ConversionError.exportFailed(
                    underlying: nil,
                    preset: preset
                )
            } catch is CancellationError {
                throw ConversionError.exportCancelled
            } catch ConversionError.exportCancelled {
                throw ConversionError.exportCancelled
            } catch {
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
    private static func attemptFFmpegConversionOrThrowUnavailable(
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
        try removeFileIfExists(at: outputURL)

        let availableVideoCodecs = outputSettings.videoCodecCandidates.filter { introspection.videoEncoders.contains($0) }
        let availableAudioCodecs = outputSettings.audioCodecCandidates.filter { introspection.audioEncoders.contains($0) }

        let videoCodecs: [String?]
        if availableVideoCodecs.isEmpty {
            videoCodecs = outputSettings.containerFormat.allowsFFmpegAutomaticVideoCodec ? [nil] : []
        } else {
            videoCodecs = availableVideoCodecs.map { Optional($0) }
        }

        let audioCodecs: [String?]
        if availableAudioCodecs.isEmpty {
            audioCodecs = outputSettings.containerFormat.allowsFFmpegAutomaticAudioCodec ? [nil] : []
        } else {
            audioCodecs = availableAudioCodecs.map { Optional($0) }
        }

        guard !videoCodecs.isEmpty else {
            throw ConversionError.ffmpegFailed(-1, "No supported video encoder found for selected format.")
        }
        guard !audioCodecs.isEmpty else {
            throw ConversionError.ffmpegFailed(-1, "No supported audio encoder found for selected format.")
        }

        var lastError: Error?
        for videoCodec in videoCodecs {
            for audioCodec in audioCodecs {
                try Task.checkCancellation()

                do {
                    try await runFFmpeg(
                        ffmpegPath: ffmpegPath,
                        inputURL: inputURL,
                        outputURL: outputURL,
                        outputSettings: outputSettings,
                        videoCodec: videoCodec,
                        audioCodec: audioCodec,
                        inputDurationSeconds: inputDurationSeconds,
                        onProgress: onProgress
                    )
                    return
                } catch is CancellationError {
                    throw ConversionError.exportCancelled
                } catch ConversionError.exportCancelled {
                    throw ConversionError.exportCancelled
                } catch {
                    lastError = error
                    try? removeFileIfExists(at: outputURL)
                }
            }
        }

        throw lastError ?? ConversionError.ffmpegFailed(-1, "No supported video/audio encoder combination found.")
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
        let args = buildFFmpegArguments(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            videoCodec: videoCodec,
            audioCodec: audioCodec
        )

        try Task.checkCancellation()
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
        try Task.checkCancellation()

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

    private static func buildFFmpegArguments(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        videoCodec: String?,
        audioCodec: String?
    ) -> [String] {
        var args = [
            "-y",
            "-progress", "pipe:1",
            "-nostats",
            "-i", inputURL.path
        ]

        if let videoCodec {
            args.append(contentsOf: ["-c:v", videoCodec])
        }

        appendVideoEncodingArguments(&args, outputSettings: outputSettings)
        appendAudioEncodingArguments(&args, outputSettings: outputSettings, audioCodec: audioCodec)

        args.append(contentsOf: [
            "-pix_fmt", "yuv420p"
        ])
        if outputSettings.containerFormat.supportsFastStart {
            args.append(contentsOf: ["-movflags", "+faststart"])
        }
        if let preferredMuxer = outputSettings.containerFormat.preferredFFmpegMuxer {
            args.append(contentsOf: ["-f", preferredMuxer])
        }
        args.append(outputURL.path)

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

        if outputSettings.useHEVCTag && outputSettings.containerFormat.supportsHEVCTag {
            args.append(contentsOf: ["-tag:v", "hvc1"])
        }
    }

    private static func appendAudioEncodingArguments(
        _ args: inout [String],
        outputSettings: VideoOutputSettings,
        audioCodec: String?
    ) {
        if let audioCodec {
            args.append(contentsOf: ["-c:a", audioCodec])
        }

        if let sampleRate = outputSettings.sampleRate {
            args.append(contentsOf: ["-ar", "\(sampleRate)"])
        }

        if let channels = outputSettings.audioChannels {
            args.append(contentsOf: ["-ac", "\(channels)"])
        }

        if let audioBitRate = outputSettings.audioBitRateKbps {
            args.append(contentsOf: ["-b:a", "\(audioBitRate)k"])
        }
    }

    private struct FFmpegIntrospection {
        let videoEncoders: Set<String>
        let audioEncoders: Set<String>
        let muxers: Set<String>
        let muxerExtensions: [String: [String]]
    }

    private struct FFmpegMuxerDescriptor {
        let name: String
        let description: String
    }

    private static func ffmpegDiscoveredFormats(from introspection: FFmpegIntrospection) -> [VideoFormatOption] {
        var formats: [VideoFormatOption] = []

        for (muxer, extensions) in introspection.muxerExtensions {
            for fileExtension in extensions where VideoFormatOption.isLikelyVideoFileExtension(fileExtension) {
                formats.append(VideoFormatOption.fromFFmpegExtension(fileExtension, muxer: muxer))
            }
        }

        return VideoFormatOption.deduplicatedAndSorted(formats)
    }

    private static func isFFmpegFormatSupported(_ format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return format.avFileType != nil
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        return hasMuxer
    }

    private static func inspectFFmpeg(at ffmpegPath: String) throws -> FFmpegIntrospection {
        if let cached = ffmpegIntrospectionCacheQueue.sync(execute: { ffmpegIntrospectionCache[ffmpegPath] }) {
            return cached
        }

        let encodersResult = runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-encoders"])
        let muxersResult = runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-muxers"])

        guard encodersResult.terminationStatus == 0 else {
            throw ConversionError.ffmpegFailed(encodersResult.terminationStatus, encodersResult.output)
        }
        guard muxersResult.terminationStatus == 0 else {
            throw ConversionError.ffmpegFailed(muxersResult.terminationStatus, muxersResult.output)
        }

        let videoEncoders = parseFFmpegEncoders(from: encodersResult.output, mediaFlag: "V")
        let audioEncoders = parseFFmpegEncoders(from: encodersResult.output, mediaFlag: "A")
        let muxerDescriptors = parseFFmpegMuxerDescriptors(from: muxersResult.output)
        let muxers = Set(muxerDescriptors.map(\.name))
        let muxerExtensions = parseFFmpegVideoMuxerExtensions(
            ffmpegPath: ffmpegPath,
            muxerDescriptors: muxerDescriptors
        )

        let introspection = FFmpegIntrospection(
            videoEncoders: videoEncoders,
            audioEncoders: audioEncoders,
            muxers: muxers,
            muxerExtensions: muxerExtensions
        )

        ffmpegIntrospectionCacheQueue.sync {
            ffmpegIntrospectionCache[ffmpegPath] = introspection
        }
        return introspection
    }

    private static func parseFFmpegEncoders(from output: String, mediaFlag: Character) -> Set<String> {
        var encoders = Set<String>()

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { continue }

            let flags = String(parts[0])
            guard flags.count >= 6, flags.first == mediaFlag else { continue }
            encoders.insert(String(parts[1]))
        }

        return encoders
    }

    private static func parseFFmpegMuxerDescriptors(from output: String) -> [FFmpegMuxerDescriptor] {
        var descriptors: [FFmpegMuxerDescriptor] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(maxSplits: 2, whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { continue }

            let flags = String(parts[0])
            guard flags.contains("E") else { continue }

            let muxerNames = String(parts[1])
                .split(separator: ",")
                .map { String($0).lowercased() }
                .filter { !$0.isEmpty }
            let description = parts.count == 3 ? String(parts[2]).lowercased() : ""

            for muxer in muxerNames {
                descriptors.append(FFmpegMuxerDescriptor(name: muxer, description: description))
            }
        }

        return descriptors
    }

    private static func parseFFmpegVideoMuxerExtensions(
        ffmpegPath: String,
        muxerDescriptors: [FFmpegMuxerDescriptor]
    ) -> [String: [String]] {
        var byMuxer: [String: [String]] = [:]
        var visited = Set<String>()

        for descriptor in muxerDescriptors {
            guard visited.insert(descriptor.name).inserted else { continue }
            guard isLikelyVideoMuxer(descriptor) else { continue }

            let help = runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-h", "muxer=\(descriptor.name)"])
            guard help.terminationStatus == 0 else { continue }

            var extensions = parseFFmpegMuxerExtensions(from: help.output)
            if extensions.isEmpty, VideoFormatOption.isLikelyVideoFileExtension(descriptor.name) {
                extensions = [descriptor.name]
            }
            guard !extensions.isEmpty else { continue }
            byMuxer[descriptor.name] = extensions
        }

        return byMuxer
    }

    private static func parseFFmpegMuxerExtensions(from output: String) -> [String] {
        var collecting = false
        var buffer = ""

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if !collecting {
                guard let range = trimmed.range(of: "Common extensions:", options: [.caseInsensitive]) else { continue }
                collecting = true
                buffer += String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                buffer += " " + trimmed
            }

            if buffer.contains(".") {
                break
            }
        }

        guard !buffer.isEmpty else { return [] }
        if let periodIndex = buffer.firstIndex(of: ".") {
            buffer = String(buffer[..<periodIndex])
        }

        let allowed = CharacterSet.alphanumerics
        var seen = Set<String>()
        var extensions: [String] = []

        for token in buffer.split(separator: ",") {
            let cleanedScalars = token
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .unicodeScalars
                .filter { allowed.contains($0) }
            let normalized = String(String.UnicodeScalarView(cleanedScalars)).lowercased()
            guard !normalized.isEmpty else { continue }
            guard seen.insert(normalized).inserted else { continue }
            extensions.append(normalized)
        }

        return extensions
    }

    private static func isLikelyVideoMuxer(_ descriptor: FFmpegMuxerDescriptor) -> Bool {
        let name = descriptor.name.lowercased()
        let description = descriptor.description.lowercased()

        let explicitVideoMuxers: Set<String> = [
            "3gp", "avi", "flv", "ipod", "matroska", "mov", "mp4", "mpeg", "mpegts", "ogg", "webm"
        ]
        if explicitVideoMuxers.contains(name) {
            return true
        }

        let keywords = [
            "video", "quicktime", "matroska", "webm", "mpeg", "movie", "avi", "flv", "ogg"
        ]
        return keywords.contains(where: { description.contains($0) })
    }

    private static func runCommandSync(
        path: String,
        arguments: [String]
    ) -> (terminationStatus: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (-1, error.localizedDescription)
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

    private final class ProcessCancellationController: @unchecked Sendable {
        private let queue = DispatchQueue(label: "myconverter.runcommand.process")
        nonisolated(unsafe) private var process: Process?

        nonisolated func setProcess(_ process: Process) {
            queue.sync {
                self.process = process
            }
        }

        nonisolated func clearProcess() {
            queue.sync {
                process = nil
            }
        }

        nonisolated func terminateIfNeeded() {
            queue.sync {
                guard let process, process.isRunning else { return }
                process.terminate()
            }
        }
    }

    private static func runCommand(
        path: String,
        arguments: [String],
        outputLineHandler: ((String) -> Void)? = nil
    ) async throws -> (terminationStatus: Int32, output: String) {
        let cancellationController = ProcessCancellationController()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int32, String), Error>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                cancellationController.setProcess(process)

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
                        cancellationController.clearProcess()
                        continuation.resume(returning: (proc.terminationStatus, output))
                    }
                }

                do {
                    try process.run()
                } catch {
                    outputHandle.readabilityHandler = nil
                    cancellationController.clearProcess()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            cancellationController.terminateIfNeeded()
        }
    }
    #endif

    private static func removeFileIfExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func compatibleExportPresets(
        for asset: AVAsset,
        preferredPresets: [String],
        outputFileType: AVFileType
    ) async -> [String] {
        var presets: [String] = []
        for preset in preferredPresets {
            let isCompatible = await AVAssetExportSession.compatibility(
                ofExportPreset: preset,
                with: asset,
                outputFileType: outputFileType
            )
            if isCompatible {
                presets.append(preset)
            }
        }
        return presets
    }

    private static func supportedOutputFormatsWithAVFoundation(for asset: AVAsset) async -> [VideoFormatOption] {
        var supported: [VideoFormatOption] = []
        for format in VideoFormatOption.avFoundationDefaultFormats {
            guard let fileType = format.avFileType else { continue }
            let presets = await compatibleExportPresets(
                for: asset,
                preferredPresets: preferredExportPresets,
                outputFileType: fileType
            )
            if !presets.isEmpty {
                supported.append(format)
            }
        }
        return supported
    }

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
            if case let .exportFailed(underlying: underlying, _) = conversionError {
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
        let isPlayable = try await asset.load(.isPlayable)
        _ = try await asset.load(.duration)
        guard isPlayable else {
            throw ConversionError.unreadableAsset
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let hasMediaTrack = !(videoTracks.isEmpty && audioTracks.isEmpty)
        if !hasMediaTrack {
            throw ConversionError.noTracksFound
        }
    }

    private static func export(
        _ session: AVAssetExportSession,
        to outputURL: URL,
        as outputFileType: AVFileType,
        preset: String,
        onProgress: @escaping ProgressHandler
    ) async throws {
        await onProgress(0)

        let progressTask = Task {
            for await state in session.states(updateInterval: 0.15) {
                if Task.isCancelled {
                    break
                }

                switch state {
                case .pending, .waiting:
                    break
                case .exporting(let progress):
                    let fractionCompleted = min(max(progress.fractionCompleted, 0), 1)
                    await onProgress(fractionCompleted)
                @unknown default:
                    break
                }
            }
        }
        defer {
            progressTask.cancel()
        }

        do {
            try await session.export(to: outputURL, as: outputFileType)
            await onProgress(1)
        } catch is CancellationError {
            throw ConversionError.exportCancelled
        } catch {
            throw ConversionError.exportFailed(underlying: error, preset: preset)
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
    case unsupportedOutputType(VideoFormatOption)
    case exportCancelled
    case exportFailed(underlying: Error?, preset: String)
    case ffmpegUnavailable
    case ffmpegFailed(Int32, String)
    case outputSaveFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "Failed to read input files."
        case .unreadableAsset:
            return "Could not parse input video file."
        case .noTracksFound:
            return "No video/audio tracks found."
        case .invalidCustomVideoBitRate:
            return "Custom Video Bit Rate must be an integer greater than 1 (Kbps)."
        case .noCompatiblePreset:
            return "No compatible export preset found in AVFoundation."
        case .cannotCreateExportSession:
            return "Could not create conversion session."
        case .unsupportedOutputType(let format):
            return "\(format.displayName) output is not supported on this device."
        case .exportCancelled:
            return "Conversion cancelled."
        case .ffmpegUnavailable:
            return "AVFoundation cannot open this source and ffmpeg was not found."
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
        case .unsupportedOutputType(let format):
            return "Does not allow .\(format.fileExtension) as outputFileType."
        case .exportFailed(let underlying, let preset):
            if let underlying {
                return "Preset: \(preset), Detail: \(underlying.localizedDescription)"
            }
            return "Preset: \(preset)"
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
            return "Input file parser failed (codec/container might be unsupported)."
        case .unsupportedSource:
            return "Unsupported codec/container for this source."
        case .noTracksFound:
            return "Video/Audio track not detected."
        }
    }
}
