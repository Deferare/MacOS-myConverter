import Foundation
import AVFoundation

struct VideoOutputSettings {
    let containerFormat: VideoFormatOption
    let videoCodecCandidates: [String]
    let useHEVCTag: Bool
    let resolution: (width: Int, height: Int)?
    let frameRate: Int?
    let gifPlaybackSpeed: Double?
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

struct AudioOutputSettings {
    let containerFormat: AudioFormatOption
    let audioCodecCandidates: [String]
    let audioChannels: Int?
    let sampleRate: Int?
    let audioBitRateKbps: Int?
}

struct AudioSourceCapabilities {
    let availableOutputFormats: [AudioFormatOption]
    let warningMessage: String?
    let errorMessage: String?
}

enum VideoConversionEngine {
    typealias ProgressHandler = @Sendable (Double) async -> Void
    private static let ffmpegIntrospectionCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.introspection.cache")
    nonisolated(unsafe) private static var ffmpegIntrospectionCache: [String: FFmpegIntrospection] = [:]
    private static let ffmpegPathCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.path.cache")
    nonisolated(unsafe) private static var ffmpegPathCache: String?? = nil
    nonisolated(unsafe) private static var ffmpegPathLookupTime: UInt64 = 0
    private static let ffmpegPathNilCacheTTL: UInt64 = 30_000_000_000
    private static let capabilityCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.capability.cache")
    nonisolated(unsafe) private static var defaultVideoFormatsCache: [String: [VideoFormatOption]] = [:]
    nonisolated(unsafe) private static var defaultAudioFormatsCache: [String: [AudioFormatOption]] = [:]
    nonisolated(unsafe) private static var videoEncoderOptionsCache: [String: [VideoEncoderOption]] = [:]
    nonisolated(unsafe) private static var videoFormatAudioEncoderOptionsCache: [String: [AudioEncoderOption]] = [:]
    nonisolated(unsafe) private static var audioFormatEncoderOptionsCache: [String: [AudioEncoderOption]] = [:]
    private static let preferredExportPresets = [
        AVAssetExportPresetPassthrough,
        AVAssetExportPresetHighestQuality,
        AVAssetExportPresetMediumQuality,
        AVAssetExportPresetLowQuality
    ]

    static func defaultOutputFormats() -> [VideoFormatOption] {
        let avFormats = VideoFormatOption.avFoundationDefaultFormats

        guard let ffmpegPath = findFFmpegPath() else {
            return avFormats
        }

        if let cached = capabilityCacheQueue.sync(execute: { defaultVideoFormatsCache[ffmpegPath] }) {
            return cached
        }

        guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
            return avFormats
        }

        let discovered = ffmpegDiscoveredFormats(from: introspection)
        let candidates = VideoFormatOption.deduplicatedAndSorted(avFormats + VideoFormatOption.ffmpegKnownFormats + discovered)
        let supportedFFmpegFormats = candidates.filter { isFFmpegFormatSupported($0, introspection: introspection) }
        let resolved = VideoFormatOption.deduplicatedAndSorted(supportedFFmpegFormats + avFormats)

        capabilityCacheQueue.sync {
            defaultVideoFormatsCache[ffmpegPath] = resolved
        }
        return resolved
    }

    static func availableVideoEncoders(for format: VideoFormatOption) -> [VideoEncoderOption] {
        if !format.supportsVideoEncoderSelection {
            return [.auto]
        }

        guard let ffmpegPath = findFFmpegPath() else {
            return [.auto]
        }

        let cacheKey = makeCapabilityCacheKey(path: ffmpegPath, normalizedID: format.normalizedID)
        if let cached = capabilityCacheQueue.sync(execute: { videoEncoderOptionsCache[cacheKey] }) {
            return cached
        }

        guard let introspection = try? inspectFFmpeg(at: ffmpegPath),
              isFFmpegFormatSupported(format, introspection: introspection) else {
            let fallback = format.avFileType == nil ? [VideoEncoderOption]() : [.auto]
            capabilityCacheQueue.sync {
                videoEncoderOptionsCache[cacheKey] = fallback
            }
            return fallback
        }

        let explicitOptions = VideoEncoderOption.allCases.filter { option in
            guard option != .auto else { return false }
            return option.isCompatible(with: format) &&
                option.codecCandidates.contains(where: { introspection.videoEncoders.contains($0) })
        }

        var resolved = explicitOptions
        if format.allowsFFmpegAutomaticVideoCodec, !explicitOptions.isEmpty {
            resolved.insert(.auto, at: 0)
        }

        capabilityCacheQueue.sync {
            videoEncoderOptionsCache[cacheKey] = resolved
        }
        return resolved
    }

    static func availableAudioEncoders(for format: VideoFormatOption) -> [AudioEncoderOption] {
        if !format.supportsAudioTrack {
            return []
        }

        guard let ffmpegPath = findFFmpegPath() else {
            return [.auto]
        }

        let cacheKey = makeCapabilityCacheKey(path: ffmpegPath, normalizedID: format.normalizedID)
        if let cached = capabilityCacheQueue.sync(execute: { videoFormatAudioEncoderOptionsCache[cacheKey] }) {
            return cached
        }

        guard let introspection = try? inspectFFmpeg(at: ffmpegPath),
              isFFmpegFormatSupported(format, introspection: introspection) else {
            let fallback = format.avFileType == nil ? [AudioEncoderOption]() : [.auto]
            capabilityCacheQueue.sync {
                videoFormatAudioEncoderOptionsCache[cacheKey] = fallback
            }
            return fallback
        }

        let explicitOptions = AudioEncoderOption.allCases.filter { option in
            guard option != .auto else { return false }
            return option.isCompatible(with: format) &&
                option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
        }

        var resolved = explicitOptions
        if format.allowsFFmpegAutomaticAudioCodec, !explicitOptions.isEmpty {
            resolved.insert(.auto, at: 0)
        }

        capabilityCacheQueue.sync {
            videoFormatAudioEncoderOptionsCache[cacheKey] = resolved
        }
        return resolved
    }

    static func defaultAudioOutputFormats() -> [AudioFormatOption] {
        let knownFormats = AudioFormatOption.ffmpegKnownFormats

        guard let ffmpegPath = findFFmpegPath() else {
            return knownFormats
        }

        if let cached = capabilityCacheQueue.sync(execute: { defaultAudioFormatsCache[ffmpegPath] }) {
            return cached
        }

        guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
            return knownFormats
        }

        let discovered = ffmpegDiscoveredAudioFormats(from: introspection)
        let candidates = AudioFormatOption.deduplicatedAndSorted(knownFormats + discovered)
        let resolved = candidates.filter { isFFmpegAudioFormatSupported($0, introspection: introspection) }
        capabilityCacheQueue.sync {
            defaultAudioFormatsCache[ffmpegPath] = resolved
        }
        return resolved
    }

    static func availableAudioEncoders(for format: AudioFormatOption) -> [AudioEncoderOption] {
        guard let ffmpegPath = findFFmpegPath() else {
            return format.allowsFFmpegAutomaticAudioCodec ? [.auto] : []
        }

        let cacheKey = makeCapabilityCacheKey(path: ffmpegPath, normalizedID: format.normalizedID)
        if let cached = capabilityCacheQueue.sync(execute: { audioFormatEncoderOptionsCache[cacheKey] }) {
            return cached
        }

        guard let introspection = try? inspectFFmpeg(at: ffmpegPath),
              isFFmpegAudioFormatSupported(format, introspection: introspection) else {
            let fallback: [AudioEncoderOption] = []
            capabilityCacheQueue.sync {
                audioFormatEncoderOptionsCache[cacheKey] = fallback
            }
            return fallback
        }

        let explicitOptions = AudioEncoderOption.allCases.filter { option in
            guard option != .auto else { return false }
            return option.isCompatible(with: format) &&
                option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
        }

        var resolved = explicitOptions
        if format.allowsFFmpegAutomaticAudioCodec, !explicitOptions.isEmpty {
            resolved.insert(.auto, at: 0)
        }

        capabilityCacheQueue.sync {
            audioFormatEncoderOptionsCache[cacheKey] = resolved
        }
        return resolved
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
        OutputPathUtilities.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            in: outputDirectory
        )
    }

    static func temporaryOutputURL(for sourceURL: URL, format: VideoFormatOption) -> URL {
        OutputPathUtilities.temporaryOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension
        )
    }

    static func uniqueOutputURL(
        for sourceURL: URL,
        format: AudioFormatOption,
        in outputDirectory: URL
    ) -> URL {
        OutputPathUtilities.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            in: outputDirectory
        )
    }

    static func temporaryOutputURL(for sourceURL: URL, format: AudioFormatOption) -> URL {
        OutputPathUtilities.temporaryOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension
        )
    }

    static func saveConvertedOutput(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        do {
            return try OutputPathUtilities.saveConvertedOutput(from: sourceURL, to: destinationURL)
        } catch let saveError as OutputPathUtilities.SaveOutputError {
            switch saveError {
            case let .outputSaveFailed(path, message):
                throw ConversionError.outputSaveFailed(path, message)
            }
        }
    }

    static func isFFmpegAvailable() -> Bool {
        return findFFmpegPath() != nil
    }

    static func sourceCapabilitiesForAudio(for inputURL: URL) async -> AudioSourceCapabilities {
        let defaultFormats = defaultAudioOutputFormats()

        guard let ffmpegPath = findFFmpegPath() else {
            return AudioSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "Audio conversion requires ffmpeg, but ffmpeg was not found."
            )
        }

        guard !defaultFormats.isEmpty else {
            return AudioSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "No compatible audio output format is available with the current ffmpeg build."
            )
        }

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetHasAudioTrack(asset)
            return AudioSourceCapabilities(
                availableOutputFormats: defaultFormats,
                warningMessage: nil,
                errorMessage: nil
            )
        } catch ConversionError.noTracksFound {
            return AudioSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "No audio track found in this source."
            )
        } catch {
            let hasAudioTrack = await ffmpegCanReadMappedStream(
                ffmpegPath: ffmpegPath,
                inputURL: inputURL,
                mapSpecifier: "0:a:0",
                frameArguments: ["-frames:a", "1"]
            )

            if hasAudioTrack {
                return AudioSourceCapabilities(
                    availableOutputFormats: defaultFormats,
                    warningMessage: "Could not analyze this source with AVFoundation. ffmpeg conversion will be attempted.",
                    errorMessage: nil
                )
            }

            return AudioSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "No readable audio track found in this source."
            )
        }
    }

    static func sourceCapabilities(for inputURL: URL) async -> VideoSourceCapabilities {
        let ffmpegPath = findFFmpegPath()
        let ffmpegAvailable = ffmpegPath != nil
        let asset = AVURLAsset(url: inputURL)
        let defaultFormats = defaultOutputFormats()

        do {
            try await ensureAssetHasVideoTrack(asset)
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
        } catch ConversionError.noVideoTrackFound {
            return VideoSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "No video track found in this source."
            )
        } catch {
            if let ffmpegPath {
                let hasVideoTrack = await ffmpegCanReadMappedStream(
                    ffmpegPath: ffmpegPath,
                    inputURL: inputURL,
                    mapSpecifier: "0:v:0",
                    frameArguments: ["-frames:v", "1"]
                )

                if !hasVideoTrack {
                    return VideoSourceCapabilities(
                        availableOutputFormats: [],
                        warningMessage: nil,
                        errorMessage: "No readable video track found in this source."
                    )
                }

                return VideoSourceCapabilities(
                    availableOutputFormats: defaultFormats,
                    warningMessage: "Could not analyze this source with AVFoundation. ffmpeg conversion will be attempted.",
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
        try OutputPathUtilities.removeFileIfExists(at: outputURL)
        let outputFileType = outputSettings.containerFormat.avFileType

        if outputFileType == nil {
            return try await attemptFFmpegConversionOrThrowUnavailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                onProgress: onProgress
            )
        }

        if let converted = try await attemptFFmpegConversion(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        ) {
            return converted
        }

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetReadable(asset)
        } catch {
            if isUnsupportedMediaFormatError(error) {
                return try await attemptFFmpegConversionOrThrowUnavailable(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: inputDurationSeconds,
                    onProgress: onProgress
                )
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
            return try await attemptFFmpegConversionOrThrowUnavailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                onProgress: onProgress
            )
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

        throw lastError ?? ConversionError.unsupportedSource
    }

    static func convertAudio(
        inputURL: URL,
        outputURL: URL,
        outputSettings: AudioOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)

        guard let ffmpegPath = findFFmpegPath() else {
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
        try OutputPathUtilities.removeFileIfExists(at: outputURL)
        let stagedInputURL = try stageInputForFFmpeg(inputURL)
        defer {
            try? OutputPathUtilities.removeFileIfExists(at: stagedInputURL)
        }

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

        var lastError: Error?
        for videoCodec in videoCodecs {
            for audioCodec in audioCodecs {
                if let error = try await attemptFFmpegOperation(
                    outputURL: outputURL,
                    operation: {
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
                    }
                ) {
                    lastError = error
                    continue
                }

                return
            }
        }

        throw lastError ?? ConversionError.ffmpegFailed(-1, "No supported video/audio encoder combination found.")
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
        let stagedInputURL = try stageInputForFFmpeg(inputURL)
        defer {
            try? OutputPathUtilities.removeFileIfExists(at: stagedInputURL)
        }

        let availableAudioCodecs = outputSettings.audioCodecCandidates.filter { introspection.audioEncoders.contains($0) }
        let audioCodecs = codecCandidates(
            availableCodecs: availableAudioCodecs,
            allowAutomatic: outputSettings.containerFormat.allowsFFmpegAutomaticAudioCodec
        )

        guard !audioCodecs.isEmpty else {
            throw ConversionError.ffmpegFailed(-1, "No supported audio encoder found for selected format.")
        }

        var lastError: Error?
        for audioCodec in audioCodecs {
            if let error = try await attemptFFmpegOperation(
                outputURL: outputURL,
                operation: {
                    try await runAudioFFmpeg(
                        ffmpegPath: ffmpegPath,
                        inputURL: stagedInputURL,
                        outputURL: outputURL,
                        outputSettings: outputSettings,
                        audioCodec: audioCodec,
                        inputDurationSeconds: inputDurationSeconds,
                        onProgress: onProgress
                    )
                }
            ) {
                lastError = error
                continue
            }

            return
        }

        throw lastError ?? ConversionError.ffmpegFailed(-1, "No supported audio encoder found for selected format.")
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

    private static func stageInputForFFmpeg(_ inputURL: URL) throws -> URL {
        do {
            return try OutputPathUtilities.stageInputURL(for: inputURL)
        } catch let stagingError as OutputPathUtilities.StagedInputError {
            switch stagingError {
            case .stagingDirectoryCreationFailed(let path, let message):
                throw ConversionError.ffmpegFailed(
                    -1,
                    "Failed to prepare ffmpeg staging directory (\(path)): \(message)"
                )
            case .stagingCopyFailed(let sourcePath, let destinationPath, let message):
                throw ConversionError.ffmpegFailed(
                    -1,
                    "Failed to stage input file for ffmpeg. Source: \(sourcePath), Destination: \(destinationPath), Detail: \(message)"
                )
            }
        } catch {
            throw ConversionError.ffmpegFailed(
                -1,
                "Failed to stage input file for ffmpeg: \(error.localizedDescription)"
            )
        }
    }

    private static func ffmpegCanReadMappedStream(
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

        guard let result = try? await runCommand(path: ffmpegPath, arguments: arguments) else {
            return false
        }

        return result.terminationStatus == 0
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
        let result = try await runCommand(path: ffmpegPath, arguments: arguments) { line in
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

    private static func ffmpegDiscoveredAudioFormats(from introspection: FFmpegIntrospection) -> [AudioFormatOption] {
        var formats: [AudioFormatOption] = []

        for (muxer, extensions) in introspection.muxerExtensions {
            for fileExtension in extensions where AudioFormatOption.isLikelyAudioFileExtension(fileExtension) {
                formats.append(AudioFormatOption.fromFFmpegExtension(fileExtension, muxer: muxer))
            }
        }

        return AudioFormatOption.deduplicatedAndSorted(formats)
    }

    private static func isFFmpegFormatSupported(_ format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return format.avFileType != nil
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        guard hasMuxer else { return false }
        guard hasCompatibleVideoEncoder(format, introspection: introspection) else { return false }
        return hasCompatibleAudioEncoder(for: format, introspection: introspection)
    }

    private static func isFFmpegAudioFormatSupported(_ format: AudioFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return hasCompatibleAudioEncoder(format, introspection: introspection)
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        guard hasMuxer else { return false }
        return hasCompatibleAudioEncoder(format, introspection: introspection)
    }

    private static func hasCompatibleAudioEncoder(_ format: AudioFormatOption, introspection: FFmpegIntrospection) -> Bool {
        AudioEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
        }
    }

    private static func hasCompatibleVideoEncoder(_ format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if !format.supportsVideoEncoderSelection {
            return format.allowsFFmpegAutomaticVideoCodec
        }

        return VideoEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.videoEncoders.contains($0) })
        }
    }

    private static func hasCompatibleAudioEncoder(for format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        guard format.supportsAudioTrack else { return true }

        return AudioEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
        }
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
            guard isLikelyVideoMuxer(descriptor) || isLikelyAudioMuxer(descriptor) else { continue }

            let help = runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-h", "muxer=\(descriptor.name)"])
            guard help.terminationStatus == 0 else { continue }

            var extensions = parseFFmpegMuxerExtensions(from: help.output)
            if extensions.isEmpty,
               VideoFormatOption.isLikelyVideoFileExtension(descriptor.name) ||
                AudioFormatOption.isLikelyAudioFileExtension(descriptor.name) {
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
            "3gp", "avi", "flv", "gif", "ipod", "matroska", "mov", "mp4", "mpeg", "mpegts", "ogg", "webm"
        ]
        if explicitVideoMuxers.contains(name) {
            return true
        }

        let keywords = [
            "video", "quicktime", "matroska", "webm", "mpeg", "movie", "avi", "flv", "ogg", "gif", "animation"
        ]
        return keywords.contains(where: { description.contains($0) })
    }

    private static func isLikelyAudioMuxer(_ descriptor: FFmpegMuxerDescriptor) -> Bool {
        let name = descriptor.name.lowercased()
        let description = descriptor.description.lowercased()

        let explicitAudioMuxers: Set<String> = [
            "aac", "ac3", "adts", "aiff", "caf", "flac", "ipod", "matroska", "mp3", "ogg", "opus", "wav"
        ]
        if explicitAudioMuxers.contains(name) {
            return true
        }

        let keywords = [
            "audio", "sound", "aac", "mp3", "wave", "wav", "flac", "opus", "ogg", "aiff", "caf"
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
        let now = DispatchTime.now().uptimeNanoseconds
        let cacheSnapshot = ffmpegPathCacheQueue.sync {
            (ffmpegPathCache, ffmpegPathLookupTime)
        }

        if let cached = cacheSnapshot.0 {
            if let path = cached, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }

            let nilCacheAge = now >= cacheSnapshot.1 ? now - cacheSnapshot.1 : 0
            if cached == nil && nilCacheAge < ffmpegPathNilCacheTTL {
                return nil
            }
        }

        let resolved = resolveFFmpegPath()
        ffmpegPathCacheQueue.sync {
            ffmpegPathCache = resolved
            ffmpegPathLookupTime = now
        }
        return resolved
    }

    private static func resolveFFmpegPath() -> String? {
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

    private static func makeCapabilityCacheKey(path: String, normalizedID: String) -> String {
        "\(path)|\(normalizedID)"
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

    private static func ensureAssetHasVideoTrack(_ asset: AVURLAsset) async throws {
        let isPlayable = try await asset.load(.isPlayable)
        _ = try await asset.load(.duration)
        guard isPlayable else {
            throw ConversionError.unreadableAsset
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        if videoTracks.isEmpty {
            throw ConversionError.noVideoTrackFound
        }
    }

    private static func ensureAssetHasAudioTrack(_ asset: AVURLAsset) async throws {
        let isPlayable = try await asset.load(.isPlayable)
        _ = try await asset.load(.duration)
        guard isPlayable else {
            throw ConversionError.unreadableAsset
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if audioTracks.isEmpty {
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
    case noVideoTrackFound
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
        case .noVideoTrackFound:
            return "No video track found."
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
            if output.localizedCaseInsensitiveContains("unknown encoder") ||
                output.localizedCaseInsensitiveContains("encoder not found") {
                return "Selected output format is not supported by the bundled ffmpeg encoders."
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
        case .noVideoTrackFound:
            return "Video track not detected."
        }
    }
}
