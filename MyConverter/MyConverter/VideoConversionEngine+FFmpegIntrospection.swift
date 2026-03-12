import Foundation

extension VideoConversionEngine {
    nonisolated static func inspectFFmpeg(using runtime: any FFmpegRuntime) throws -> FFmpegIntrospection {
        let cacheKey = runtime.cacheIdentity
        if let cached = ffmpegIntrospectionCacheQueue.sync(execute: { ffmpegIntrospectionCache[cacheKey] }) {
            return cached
        }

        let (inFlight, shouldBuild) = ffmpegIntrospectionCacheQueue.sync { () -> (InFlightGroupedResult<FFmpegIntrospection>, Bool) in
            if let existing = ffmpegIntrospectionInFlight[cacheKey] {
                return (existing, false)
            }

            let created = InFlightGroupedResult<FFmpegIntrospection>()
            ffmpegIntrospectionInFlight[cacheKey] = created
            return (created, true)
        }

        if !shouldBuild {
            return try waitForFFmpegIntrospection(inFlight, cacheKey: cacheKey)
        }

        do {
            let introspection = try buildFFmpegIntrospection(using: runtime)
            finishFFmpegIntrospection(inFlight, cacheKey: cacheKey, result: .success(introspection))
            return introspection
        } catch {
            finishFFmpegIntrospection(inFlight, cacheKey: cacheKey, result: .failure(error))
            throw error
        }
    }

    nonisolated static func inspectFFmpeg(at ffmpegPath: String) throws -> FFmpegIntrospection {
        try inspectFFmpeg(using: ProcessFFmpegRuntime(path: ffmpegPath))
    }

    nonisolated private static func buildFFmpegIntrospection(using runtime: any FFmpegRuntime) throws -> FFmpegIntrospection {
        let encodersResult = FFmpegCommandCache.run(
            runtime: runtime,
            arguments: ["-hide_banner", "-encoders"]
        )
        let muxersResult = FFmpegCommandCache.run(
            runtime: runtime,
            arguments: ["-hide_banner", "-muxers"]
        )

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
            runtime: runtime,
            muxerDescriptors: muxerDescriptors
        )

        return FFmpegIntrospection(
            videoEncoders: videoEncoders,
            audioEncoders: audioEncoders,
            muxers: muxers,
            muxerExtensions: muxerExtensions
        )
    }

    nonisolated private static func waitForFFmpegIntrospection(
        _ inFlight: InFlightGroupedResult<FFmpegIntrospection>,
        cacheKey: String
    ) throws -> FFmpegIntrospection {
        try InFlightOperationSupport.waitForGroupedResult(
            inFlight,
            cachedValue: { ffmpegIntrospectionCacheQueue.sync(execute: { ffmpegIntrospectionCache[cacheKey] }) },
            missingResultError: ConversionError.ffmpegFailed(
                -1,
                "FFmpeg introspection did not produce a result."
            )
        )
    }

    nonisolated private static func finishFFmpegIntrospection(
        _ inFlight: InFlightGroupedResult<FFmpegIntrospection>,
        cacheKey: String,
        result: Result<FFmpegIntrospection, Error>
    ) {
        InFlightOperationSupport.finishGroupedResult(
            result,
            in: inFlight,
            on: ffmpegIntrospectionCacheQueue
        ) { result in
            if case .success(let introspection) = result {
                ffmpegIntrospectionCache[cacheKey] = introspection
            }
            ffmpegIntrospectionInFlight[cacheKey] = nil
        }
    }

    nonisolated static func isFFmpegFormatSupported(_ format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return format.avFileType != nil
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        guard hasMuxer else { return false }
        guard hasCompatibleVideoEncoder(format, introspection: introspection) else { return false }
        return hasCompatibleAudioEncoder(for: format, introspection: introspection)
    }

    nonisolated static func isFFmpegAudioFormatSupported(_ format: AudioFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if format.ffmpegRequiredMuxers.isEmpty {
            return hasCompatibleAudioEncoder(format, introspection: introspection)
        }

        let hasMuxer = format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })
        guard hasMuxer else { return false }
        return hasCompatibleAudioEncoder(format, introspection: introspection)
    }

    nonisolated static func ffmpegDiscoveredFormats(from introspection: FFmpegIntrospection) -> [VideoFormatOption] {
        var formats: [VideoFormatOption] = []

        for (muxer, extensions) in introspection.muxerExtensions {
            for fileExtension in extensions where VideoFormatOption.isLikelyVideoFileExtension(fileExtension) {
                formats.append(VideoFormatOption.fromFFmpegExtension(fileExtension, muxer: muxer))
            }
        }

        return VideoFormatOption.deduplicatedAndSorted(formats)
    }

    nonisolated static func ffmpegDiscoveredAudioFormats(from introspection: FFmpegIntrospection) -> [AudioFormatOption] {
        var formats: [AudioFormatOption] = []

        for (muxer, extensions) in introspection.muxerExtensions {
            for fileExtension in extensions where AudioFormatOption.isLikelyAudioFileExtension(fileExtension) {
                formats.append(AudioFormatOption.fromFFmpegExtension(fileExtension, muxer: muxer))
            }
        }

        return AudioFormatOption.deduplicatedAndSorted(formats)
    }

    nonisolated private static func hasCompatibleAudioEncoder(_ format: AudioFormatOption, introspection: FFmpegIntrospection) -> Bool {
        AudioEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
        }
    }

    nonisolated private static func hasCompatibleVideoEncoder(_ format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        if !format.supportsVideoEncoderSelection {
            return format.allowsFFmpegAutomaticVideoCodec
        }

        return VideoEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.videoEncoders.contains($0) })
        }
    }

    nonisolated private static func hasCompatibleAudioEncoder(for format: VideoFormatOption, introspection: FFmpegIntrospection) -> Bool {
        guard format.supportsAudioTrack else { return true }

        return AudioEncoderOption.allCases.contains { option in
            guard option != .auto else { return false }
            guard option.isCompatible(with: format) else { return false }
            return option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
        }
    }

    nonisolated private static func parseFFmpegEncoders(from output: String, mediaFlag: Character) -> Set<String> {
        FFmpegParsingSupport.parseEncoders(from: output, mediaFlag: mediaFlag)
    }

    nonisolated private static func parseFFmpegMuxerDescriptors(from output: String) -> [FFmpegMuxerDescriptor] {
        FFmpegParsingSupport.parseMuxerDescriptors(
            from: output,
            lowercaseDescription: true
        )
        .map { descriptor in
            FFmpegMuxerDescriptor(name: descriptor.name, description: descriptor.description)
        }
    }

    nonisolated private static func parseFFmpegVideoMuxerExtensions(
        runtime: any FFmpegRuntime,
        muxerDescriptors: [FFmpegMuxerDescriptor]
    ) -> [String: [String]] {
        var byMuxer: [String: [String]] = [:]
        var visited = Set<String>()

        for descriptor in muxerDescriptors {
            guard visited.insert(descriptor.name).inserted else { continue }
            guard isLikelyVideoMuxer(descriptor) || isLikelyAudioMuxer(descriptor) else { continue }

            let help = FFmpegCommandCache.run(
                runtime: runtime,
                arguments: ["-hide_banner", "-h", "muxer=\(descriptor.name)"]
            )
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

    nonisolated private static func parseFFmpegMuxerExtensions(from output: String) -> [String] {
        FFmpegParsingSupport.parseMuxerExtensions(from: output, maxTokenLength: nil)
    }

    nonisolated private static func isLikelyVideoMuxer(_ descriptor: FFmpegMuxerDescriptor) -> Bool {
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

    nonisolated private static func isLikelyAudioMuxer(_ descriptor: FFmpegMuxerDescriptor) -> Bool {
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
}
