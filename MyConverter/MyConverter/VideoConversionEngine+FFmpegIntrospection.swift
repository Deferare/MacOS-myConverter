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

    nonisolated static func buildFFmpegIntrospection(using runtime: any FFmpegRuntime) throws -> FFmpegIntrospection {
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
}
