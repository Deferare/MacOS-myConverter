import Foundation

extension VideoConversionEngine {
    nonisolated static func inspectFFmpeg(using runtime: any FFmpegRuntime) throws -> FFmpegIntrospection {
        let cacheKey = runtime.cacheIdentity
        return try InFlightOperationSupport.loadCachedGroupedValue(
            cacheKey: cacheKey,
            on: ffmpegIntrospectionCacheQueue,
            cachedValue: { ffmpegIntrospectionCache[cacheKey] },
            existingInFlight: { ffmpegIntrospectionInFlight[cacheKey] },
            storeInFlight: { ffmpegIntrospectionInFlight[cacheKey] = $0 },
            missingResultError: ConversionError.ffmpegFailed(
                -1,
                "FFmpeg introspection did not produce a result."
            ),
            build: { try buildFFmpegIntrospection(using: runtime) },
            storeCachedValue: { ffmpegIntrospectionCache[cacheKey] = $0 }
        )
    }

    nonisolated private static func buildFFmpegIntrospection(using runtime: any FFmpegRuntime) throws -> FFmpegIntrospection {
        let encodersOutput = try FFmpegParsingSupport.runCommandOutput(
            runtime: runtime,
            arguments: ["-hide_banner", "-encoders"],
            makeError: ConversionError.ffmpegFailed
        )
        let muxersOutput = try FFmpegParsingSupport.runCommandOutput(
            runtime: runtime,
            arguments: ["-hide_banner", "-muxers"],
            makeError: ConversionError.ffmpegFailed
        )

        let videoEncoders = FFmpegParsingSupport.parseEncoders(from: encodersOutput, mediaFlag: "V")
        let audioEncoders = FFmpegParsingSupport.parseEncoders(from: encodersOutput, mediaFlag: "A")
        let muxerDescriptors = FFmpegParsingSupport.parseMuxerDescriptors(
            from: muxersOutput,
            lowercaseDescription: true
        )
        let muxerExtensions = FFmpegParsingSupport.collectMuxerExtensions(
            runtime: runtime,
            muxerDescriptors: muxerDescriptors,
            maxTokenLength: nil,
            shouldInclude: { descriptor in
                isLikelyVideoMuxer(descriptor) || isLikelyAudioMuxer(descriptor)
            },
            fallbackExtension: { descriptor in
                if VideoFormatOption.isLikelyVideoFileExtension(descriptor.name) ||
                    AudioFormatOption.isLikelyAudioFileExtension(descriptor.name) {
                    return descriptor.name
                }
                return nil
            }
        )

        return FFmpegIntrospection(
            videoEncoders: videoEncoders,
            audioEncoders: audioEncoders,
            muxers: Set(muxerDescriptors.map(\.name)),
            muxerExtensions: muxerExtensions
        )
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
        VideoFormatOption.deduplicatedAndSorted(
            FFmpegParsingSupport.discoveredFormats(
                from: introspection,
                includeExtension: VideoFormatOption.isLikelyVideoFileExtension(_:),
                makeFormat: VideoFormatOption.fromFFmpegExtension(_:muxer:)
            )
        )
    }

    nonisolated static func ffmpegDiscoveredAudioFormats(from introspection: FFmpegIntrospection) -> [AudioFormatOption] {
        AudioFormatOption.deduplicatedAndSorted(
            FFmpegParsingSupport.discoveredFormats(
                from: introspection,
                includeExtension: AudioFormatOption.isLikelyAudioFileExtension(_:),
                makeFormat: AudioFormatOption.fromFFmpegExtension(_:muxer:)
            )
        )
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
