import Foundation

extension ImageConversionEngine {
    nonisolated static func inspectFFmpeg(using runtime: any FFmpegRuntime) throws -> FFmpegIntrospection {
        let cacheKey = runtime.cacheIdentity
        if let cached = introspectionCacheQueue.sync(execute: { introspectionCache[cacheKey] }) {
            return cached
        }

        let (inFlight, shouldBuild) = introspectionCacheQueue.sync { () -> (InFlightGroupedResult<FFmpegIntrospection>, Bool) in
            if let existing = introspectionInFlight[cacheKey] {
                return (existing, false)
            }

            let created = InFlightGroupedResult<FFmpegIntrospection>()
            introspectionInFlight[cacheKey] = created
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
            throw ImageConversionError.ffmpegFailed(encodersResult.terminationStatus, encodersResult.output)
        }

        guard muxersResult.terminationStatus == 0 else {
            throw ImageConversionError.ffmpegFailed(muxersResult.terminationStatus, muxersResult.output)
        }

        let encoders = parseFFmpegEncoders(from: encodersResult.output)
        let muxerDescriptors = parseFFmpegMuxerDescriptors(from: muxersResult.output)
        let muxers = Set(muxerDescriptors.map(\.name))
        let muxerExtensions = parseFFmpegImageMuxerExtensions(
            runtime: runtime,
            muxerDescriptors: muxerDescriptors
        )

        return FFmpegIntrospection(
            videoEncoders: encoders,
            audioEncoders: [],
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
            cachedValue: { introspectionCacheQueue.sync(execute: { introspectionCache[cacheKey] }) },
            missingResultError: ImageConversionError.ffmpegFailed(
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
            on: introspectionCacheQueue
        ) { result in
            if case .success(let introspection) = result {
                introspectionCache[cacheKey] = introspection
            }
            introspectionInFlight[cacheKey] = nil
        }
    }

    nonisolated private static func parseFFmpegEncoders(from output: String) -> Set<String> {
        FFmpegParsingSupport.parseEncoders(from: output, mediaFlag: "V")
    }

    nonisolated private static func parseFFmpegMuxerDescriptors(from output: String) -> [FFmpegMuxerDescriptor] {
        FFmpegParsingSupport.parseMuxerDescriptors(
            from: output,
            lowercaseDescription: false
        )
        .map { descriptor in
            FFmpegMuxerDescriptor(name: descriptor.name, description: descriptor.description)
        }
    }

    nonisolated private static func parseFFmpegImageMuxerExtensions(
        runtime: any FFmpegRuntime,
        muxerDescriptors: [FFmpegMuxerDescriptor]
    ) -> [String: [String]] {
        var map: [String: [String]] = [:]
        var seenMuxers = Set<String>()

        for descriptor in muxerDescriptors {
            guard seenMuxers.insert(descriptor.name).inserted else { continue }
            guard isLikelyImageMuxer(descriptor) else { continue }

            let helpResult = FFmpegCommandCache.run(
                runtime: runtime,
                arguments: ["-hide_banner", "-h", "muxer=\(descriptor.name)"]
            )
            guard helpResult.terminationStatus == 0 else { continue }

            var extensions = parseFFmpegMuxerExtensions(from: helpResult.output)
            if extensions.isEmpty, ImageFormatOption.isLikelyImageFileExtension(descriptor.name) {
                extensions = [descriptor.name]
            }

            guard !extensions.isEmpty else { continue }
            map[descriptor.name] = extensions
        }

        return map
    }

    nonisolated private static func parseFFmpegMuxerExtensions(from output: String) -> [String] {
        FFmpegParsingSupport.parseMuxerExtensions(
            from: output,
            maxTokenLength: 16
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
