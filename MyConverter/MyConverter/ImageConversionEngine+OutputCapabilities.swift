import Foundation
import ImageIO

extension ImageConversionEngine {
    nonisolated static func defaultOutputFormats() -> [ImageFormatOption] {
        let imageIOFormats = imageIOAvailableFormats()

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return imageIOFormats
        }

        return cachedOutputFormatValue(
            readCached: { outputFormatCacheQueue.sync(execute: { defaultOutputFormatsCache[ffmpegPath] }) },
            storeCached: { resolved in
                outputFormatCacheQueue.sync {
                    defaultOutputFormatsCache[ffmpegPath] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
                return imageIOFormats
            }

            let discoveredFFmpegFormats = ffmpegDiscoveredFormats(from: introspection)
            let candidates = ImageFormatOption.deduplicatedAndSorted(
                imageIOFormats + ImageFormatOption.ffmpegKnownFormats + discoveredFFmpegFormats
            )
            let ffmpegFormats = detectFFmpegSupportedOutputFormats(
                candidateFormats: candidates,
                introspection: introspection
            )

            return mergedFormats(primary: ffmpegFormats, secondary: imageIOFormats)
        }
    }

    nonisolated static func isFFmpegFormatSupported(_ format: ImageFormatOption, ffmpegPath: String) -> Bool {
        guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
            return false
        }

        return isFFmpegFormatSupported(format, introspection: introspection)
    }

    nonisolated static func inspectFFmpeg(at ffmpegPath: String) throws -> FFmpegIntrospection {
        if let cached = introspectionCacheQueue.sync(execute: { introspectionCache[ffmpegPath] }) {
            return cached
        }

        let encodersResult = ProcessCommandRunner.runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-encoders"])
        let muxersResult = ProcessCommandRunner.runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-muxers"])

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

        let introspection = FFmpegIntrospection(
            encoders: encoders,
            muxers: muxers,
            muxerExtensions: muxerExtensions
        )

        introspectionCacheQueue.sync {
            introspectionCache[ffmpegPath] = introspection
        }

        return introspection
    }

    nonisolated private static func mergedFormats(
        primary: [ImageFormatOption],
        secondary: [ImageFormatOption]
    ) -> [ImageFormatOption] {
        ImageFormatOption.deduplicatedAndSorted(primary + secondary)
    }

    nonisolated private static func ffmpegDiscoveredFormats(from introspection: FFmpegIntrospection) -> [ImageFormatOption] {
        var discovered: [ImageFormatOption] = []

        for (muxer, extensions) in introspection.muxerExtensions {
            for ext in extensions {
                discovered.append(ImageFormatOption.fromFFmpegExtension(ext, muxer: muxer))
            }
        }

        return ImageFormatOption.deduplicatedAndSorted(discovered)
    }

    nonisolated private static func imageIOAvailableFormats() -> [ImageFormatOption] {
        cachedOutputFormatValue(
            readCached: { outputFormatCacheQueue.sync(execute: { imageIOAvailableFormatsCache }) },
            storeCached: { resolved in
                outputFormatCacheQueue.sync {
                    imageIOAvailableFormatsCache = resolved
                }
            }
        ) {
            let identifiers = (CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])
            let options = identifiers.map { ImageFormatOption.fromImageIOTypeIdentifier($0) }
            return ImageFormatOption.deduplicatedAndSorted(options)
        }
    }

    nonisolated private static func detectFFmpegSupportedOutputFormats(
        candidateFormats: [ImageFormatOption],
        introspection: FFmpegIntrospection
    ) -> [ImageFormatOption] {
        ImageFormatOption.deduplicatedAndSorted(candidateFormats).filter { format in
            isFFmpegFormatSupported(format, introspection: introspection)
        }
    }

    nonisolated private static func isFFmpegFormatSupported(
        _ format: ImageFormatOption,
        introspection: FFmpegIntrospection
    ) -> Bool {
        let hasMuxer =
            format.ffmpegRequiredMuxers.isEmpty ||
            format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })

        guard hasMuxer else { return false }

        if format.ffmpegEncoderCandidates.isEmpty {
            return format.allowsFFmpegAutomaticCodec
        }

        let hasEncoder = format.ffmpegEncoderCandidates.contains { introspection.encoders.contains($0) }
        return hasEncoder || format.allowsFFmpegAutomaticCodec
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

            let helpResult = ProcessCommandRunner.runCommandSync(
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
