import AVFoundation
import Foundation

extension VideoConversionEngine {
    private static func cachedCapabilityValue<Value>(
        readCached: () -> Value?,
        storeCached: (Value) -> Void,
        build: () -> Value
    ) -> Value {
        if let cached = readCached() {
            return cached
        }

        let resolved = build()
        storeCached(resolved)
        return resolved
    }

    private static func resolvedEncoderOptions<Option: Equatable>(
        explicitOptions: [Option],
        allowsAutomatic: Bool,
        automaticOption: Option
    ) -> [Option] {
        guard allowsAutomatic, !explicitOptions.isEmpty else {
            return explicitOptions
        }
        return [automaticOption] + explicitOptions
    }

    private static func makeVideoCapabilities(
        availableOutputFormats: [VideoFormatOption],
        warningMessage: String? = nil,
        errorMessage: String? = nil
    ) -> VideoSourceCapabilities {
        VideoSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )
    }

    private static func makeAudioCapabilities(
        availableOutputFormats: [AudioFormatOption],
        warningMessage: String? = nil,
        errorMessage: String? = nil
    ) -> AudioSourceCapabilities {
        AudioSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )
    }

    static func defaultOutputFormats() -> [VideoFormatOption] {
        let avFormats = VideoFormatOption.avFoundationDefaultFormats

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return avFormats
        }

        return cachedCapabilityValue(
            readCached: { capabilityCacheQueue.sync(execute: { defaultVideoFormatsCache[ffmpegPath] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    defaultVideoFormatsCache[ffmpegPath] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
                return avFormats
            }

            let discovered = ffmpegDiscoveredFormats(from: introspection)
            let candidates = VideoFormatOption.deduplicatedAndSorted(avFormats + VideoFormatOption.ffmpegKnownFormats + discovered)
            let supportedFFmpegFormats = candidates.filter { isFFmpegFormatSupported($0, introspection: introspection) }
            return VideoFormatOption.deduplicatedAndSorted(supportedFFmpegFormats + avFormats)
        }
    }

    static func availableVideoEncoders(for format: VideoFormatOption) -> [VideoEncoderOption] {
        if !format.supportsVideoEncoderSelection {
            return [.auto]
        }

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return [.auto]
        }

        let cacheKey = makeCapabilityCacheKey(path: ffmpegPath, normalizedID: format.normalizedID)
        return cachedCapabilityValue(
            readCached: { capabilityCacheQueue.sync(execute: { videoEncoderOptionsCache[cacheKey] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    videoEncoderOptionsCache[cacheKey] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(at: ffmpegPath),
                  isFFmpegFormatSupported(format, introspection: introspection) else {
                return format.avFileType == nil ? [VideoEncoderOption]() : [.auto]
            }

            let explicitOptions = VideoEncoderOption.allCases.filter { option in
                guard option != .auto else { return false }
                return option.isCompatible(with: format) &&
                    option.codecCandidates.contains(where: { introspection.videoEncoders.contains($0) })
            }

            return resolvedEncoderOptions(
                explicitOptions: explicitOptions,
                allowsAutomatic: format.allowsFFmpegAutomaticVideoCodec,
                automaticOption: .auto
            )
        }
    }

    static func availableAudioEncoders(for format: VideoFormatOption) -> [AudioEncoderOption] {
        if !format.supportsAudioTrack {
            return []
        }

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return [.auto]
        }

        let cacheKey = makeCapabilityCacheKey(path: ffmpegPath, normalizedID: format.normalizedID)
        return cachedCapabilityValue(
            readCached: { capabilityCacheQueue.sync(execute: { videoFormatAudioEncoderOptionsCache[cacheKey] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    videoFormatAudioEncoderOptionsCache[cacheKey] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(at: ffmpegPath),
                  isFFmpegFormatSupported(format, introspection: introspection) else {
                return format.avFileType == nil ? [AudioEncoderOption]() : [.auto]
            }

            let explicitOptions = AudioEncoderOption.allCases.filter { option in
                guard option != .auto else { return false }
                return option.isCompatible(with: format) &&
                    option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
            }

            return resolvedEncoderOptions(
                explicitOptions: explicitOptions,
                allowsAutomatic: format.allowsFFmpegAutomaticAudioCodec,
                automaticOption: .auto
            )
        }
    }

    static func defaultAudioOutputFormats() -> [AudioFormatOption] {
        let knownFormats = AudioFormatOption.ffmpegKnownFormats

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return knownFormats
        }

        return cachedCapabilityValue(
            readCached: { capabilityCacheQueue.sync(execute: { defaultAudioFormatsCache[ffmpegPath] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    defaultAudioFormatsCache[ffmpegPath] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
                return knownFormats
            }

            let discovered = ffmpegDiscoveredAudioFormats(from: introspection)
            let candidates = AudioFormatOption.deduplicatedAndSorted(knownFormats + discovered)
            return candidates.filter { isFFmpegAudioFormatSupported($0, introspection: introspection) }
        }
    }

    static func availableAudioEncoders(for format: AudioFormatOption) -> [AudioEncoderOption] {
        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return format.allowsFFmpegAutomaticAudioCodec ? [.auto] : []
        }

        let cacheKey = makeCapabilityCacheKey(path: ffmpegPath, normalizedID: format.normalizedID)
        return cachedCapabilityValue(
            readCached: { capabilityCacheQueue.sync(execute: { audioFormatEncoderOptionsCache[cacheKey] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    audioFormatEncoderOptionsCache[cacheKey] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(at: ffmpegPath),
                  isFFmpegAudioFormatSupported(format, introspection: introspection) else {
                return []
            }

            let explicitOptions = AudioEncoderOption.allCases.filter { option in
                guard option != .auto else { return false }
                return option.isCompatible(with: format) &&
                    option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
            }

            return resolvedEncoderOptions(
                explicitOptions: explicitOptions,
                allowsAutomatic: format.allowsFFmpegAutomaticAudioCodec,
                automaticOption: .auto
            )
        }
    }

    static func sourceCapabilitiesForAudio(for inputURL: URL) async -> AudioSourceCapabilities {
        let defaultFormats = defaultAudioOutputFormats()

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "Audio conversion requires ffmpeg, but ffmpeg was not found."
            )
        }

        guard !defaultFormats.isEmpty else {
            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "No compatible audio output format is available with the current ffmpeg build."
            )
        }

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetHasAudioTrack(asset)
            return makeAudioCapabilities(availableOutputFormats: defaultFormats)
        } catch ConversionError.noTracksFound {
            return makeAudioCapabilities(
                availableOutputFormats: [],
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
                return makeAudioCapabilities(availableOutputFormats: defaultFormats)
            }

            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "No readable audio track found in this source."
            )
        }
    }

    static func sourceCapabilities(for inputURL: URL) async -> VideoSourceCapabilities {
        let ffmpegPath = FFmpegBinaryLocator.findPath()
        let ffmpegAvailable = ffmpegPath != nil
        let asset = AVURLAsset(url: inputURL)
        let defaultFormats = defaultOutputFormats()

        do {
            try await ensureAssetHasVideoTrack(asset)
            let avSupported = await supportedOutputFormatsWithAVFoundation(for: asset)
            if ffmpegAvailable {
                return makeVideoCapabilities(
                    availableOutputFormats: VideoFormatOption.deduplicatedAndSorted(defaultFormats + avSupported)
                )
            }

            if avSupported.isEmpty {
                return makeVideoCapabilities(
                    availableOutputFormats: [],
                    errorMessage: "No compatible output container is available for this source."
                )
            }

            return makeVideoCapabilities(availableOutputFormats: avSupported)
        } catch ConversionError.noVideoTrackFound {
            return makeVideoCapabilities(
                availableOutputFormats: [],
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
                    return makeVideoCapabilities(
                        availableOutputFormats: [],
                        errorMessage: "No readable video track found in this source."
                    )
                }

                return makeVideoCapabilities(availableOutputFormats: defaultFormats)
            }

            return makeVideoCapabilities(
                availableOutputFormats: [],
                errorMessage: "This source cannot be opened by AVFoundation and ffmpeg is unavailable."
            )
        }
    }

    static func inspectFFmpeg(at ffmpegPath: String) throws -> FFmpegIntrospection {
        if let cached = ffmpegIntrospectionCacheQueue.sync(execute: { ffmpegIntrospectionCache[ffmpegPath] }) {
            return cached
        }

        let encodersResult = ProcessCommandRunner.runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-encoders"])
        let muxersResult = ProcessCommandRunner.runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-muxers"])

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

    static func isFFmpegFormatSupported(_ format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return format.avFileType != nil
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        guard hasMuxer else { return false }
        guard hasCompatibleVideoEncoder(format, introspection: introspection) else { return false }
        return hasCompatibleAudioEncoder(for: format, introspection: introspection)
    }

    static func isFFmpegAudioFormatSupported(_ format: AudioFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return hasCompatibleAudioEncoder(format, introspection: introspection)
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        guard hasMuxer else { return false }
        return hasCompatibleAudioEncoder(format, introspection: introspection)
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

    private static func parseFFmpegEncoders(from output: String, mediaFlag: Character) -> Set<String> {
        FFmpegParsingSupport.parseEncoders(from: output, mediaFlag: mediaFlag)
    }

    private static func parseFFmpegMuxerDescriptors(from output: String) -> [FFmpegMuxerDescriptor] {
        FFmpegParsingSupport.parseMuxerDescriptors(
            from: output,
            lowercaseDescription: true
        )
        .map { descriptor in
            FFmpegMuxerDescriptor(name: descriptor.name, description: descriptor.description)
        }
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

            let help = ProcessCommandRunner.runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-h", "muxer=\(descriptor.name)"])
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
        FFmpegParsingSupport.parseMuxerExtensions(from: output, maxTokenLength: nil)
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

    private static func makeCapabilityCacheKey(path: String, normalizedID: String) -> String {
        "\(path)|\(normalizedID)"
    }
}
