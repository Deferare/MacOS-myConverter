import Foundation

extension ImageConversionEngine {
    nonisolated static func inspectFFmpeg(using runtime: any FFmpegRuntime) throws -> FFmpegIntrospection {
        let cacheKey = runtime.cacheIdentity
        return try InFlightOperationSupport.loadCachedGroupedValue(
            cacheKey: cacheKey,
            on: introspectionCacheQueue,
            cachedValue: { introspectionCache[cacheKey] },
            existingInFlight: { introspectionInFlight[cacheKey] },
            storeInFlight: { introspectionInFlight[cacheKey] = $0 },
            missingResultError: ImageConversionError.ffmpegFailed(
                -1,
                "FFmpeg introspection did not produce a result."
            ),
            build: { try buildFFmpegIntrospection(using: runtime) },
            storeCachedValue: { introspectionCache[cacheKey] = $0 }
        )
    }

    nonisolated static func inspectFFmpeg(at ffmpegPath: String) throws -> FFmpegIntrospection {
        try inspectFFmpeg(using: ProcessFFmpegRuntime(path: ffmpegPath))
    }

    nonisolated private static func buildFFmpegIntrospection(using runtime: any FFmpegRuntime) throws -> FFmpegIntrospection {
        let encodersOutput = try FFmpegParsingSupport.runCommandOutput(
            runtime: runtime,
            arguments: ["-hide_banner", "-encoders"],
            makeError: ImageConversionError.ffmpegFailed
        )
        let muxersOutput = try FFmpegParsingSupport.runCommandOutput(
            runtime: runtime,
            arguments: ["-hide_banner", "-muxers"],
            makeError: ImageConversionError.ffmpegFailed
        )

        let encoders = FFmpegParsingSupport.parseEncoders(from: encodersOutput, mediaFlag: "V")
        let muxerDescriptors = FFmpegParsingSupport.parseMuxerDescriptors(
            from: muxersOutput,
            lowercaseDescription: false
        )
        let muxerExtensions = FFmpegParsingSupport.collectMuxerExtensions(
            runtime: runtime,
            muxerDescriptors: muxerDescriptors,
            maxTokenLength: 16,
            shouldInclude: isLikelyImageMuxer(_:),
            fallbackExtension: { descriptor in
                ImageFormatOption.isLikelyImageFileExtension(descriptor.name) ? descriptor.name : nil
            }
        )

        return FFmpegIntrospection(
            videoEncoders: encoders,
            audioEncoders: [],
            muxers: Set(muxerDescriptors.map(\.name)),
            muxerExtensions: muxerExtensions
        )
    }

    nonisolated private static func isLikelyImageMuxer(_ descriptor: FFmpegMuxerDescriptor) -> Bool {
        let name = descriptor.name.lowercased()
        let description = descriptor.description.lowercased()

        let explicitNames: Set<String> = [
            "image2",
            "gif",
            "webp",
            "avif",
            "heif",
            "apng",
            "ico",
            "jpegxl",
            "jxl"
        ]
        if explicitNames.contains(name) {
            return true
        }

        let keywords = [
            "image",
            "animation",
            "gif",
            "webp",
            "avif",
            "heif",
            "heic",
            "jpeg",
            "jpg",
            "png",
            "tiff",
            "bmp",
            "ico",
            "jxl",
            "jpegxl"
        ]

        return keywords.contains(where: { description.contains($0) })
    }
}
