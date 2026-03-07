import Foundation

extension ImageConversionEngine {
    nonisolated static func inspectFFmpeg(at ffmpegPath: String) throws -> FFmpegIntrospection {
        if let cached = introspectionCacheQueue.sync(execute: { introspectionCache[ffmpegPath] }) {
            return cached
        }

        let (inFlight, shouldBuild) = introspectionCacheQueue.sync { () -> (InFlightFFmpegIntrospection, Bool) in
            if let existing = introspectionInFlight[ffmpegPath] {
                return (existing, false)
            }

            let created = InFlightFFmpegIntrospection()
            introspectionInFlight[ffmpegPath] = created
            return (created, true)
        }

        if !shouldBuild {
            return try waitForFFmpegIntrospection(inFlight, ffmpegPath: ffmpegPath)
        }

        do {
            let introspection = try buildFFmpegIntrospection(at: ffmpegPath)
            finishFFmpegIntrospection(inFlight, ffmpegPath: ffmpegPath, result: .success(introspection))
            return introspection
        } catch {
            finishFFmpegIntrospection(inFlight, ffmpegPath: ffmpegPath, result: .failure(error))
            throw error
        }
    }

    nonisolated private static func buildFFmpegIntrospection(at ffmpegPath: String) throws -> FFmpegIntrospection {
        let encodersResult = FFmpegCommandCache.run(
            path: ffmpegPath,
            arguments: ["-hide_banner", "-encoders"]
        )
        let muxersResult = FFmpegCommandCache.run(
            path: ffmpegPath,
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
            ffmpegPath: ffmpegPath,
            muxerDescriptors: muxerDescriptors
        )

        return FFmpegIntrospection(
            encoders: encoders,
            muxers: muxers,
            muxerExtensions: muxerExtensions
        )
    }

    nonisolated private static func waitForFFmpegIntrospection(
        _ inFlight: InFlightFFmpegIntrospection,
        ffmpegPath: String
    ) throws -> FFmpegIntrospection {
        inFlight.group.wait()
        if let result = inFlight.result {
            return try result.get()
        }

        if let cached = introspectionCacheQueue.sync(execute: { introspectionCache[ffmpegPath] }) {
            return cached
        }

        throw ImageConversionError.ffmpegFailed(-1, "FFmpeg introspection did not produce a result.")
    }

    nonisolated private static func finishFFmpegIntrospection(
        _ inFlight: InFlightFFmpegIntrospection,
        ffmpegPath: String,
        result: Result<FFmpegIntrospection, Error>
    ) {
        introspectionCacheQueue.sync {
            if case .success(let introspection) = result {
                introspectionCache[ffmpegPath] = introspection
            }
            inFlight.result = result
            introspectionInFlight[ffmpegPath] = nil
            inFlight.group.leave()
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
        ffmpegPath: String,
        muxerDescriptors: [FFmpegMuxerDescriptor]
    ) -> [String: [String]] {
        var map: [String: [String]] = [:]
        var seenMuxers = Set<String>()

        for descriptor in muxerDescriptors {
            guard seenMuxers.insert(descriptor.name).inserted else { continue }
            guard isLikelyImageMuxer(descriptor) else { continue }

            let helpResult = FFmpegCommandCache.run(
                path: ffmpegPath,
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
