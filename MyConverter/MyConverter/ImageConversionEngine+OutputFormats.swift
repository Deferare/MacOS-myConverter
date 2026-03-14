import Foundation
import ImageIO

extension ImageConversionEngine {
    nonisolated static func defaultOutputFormats() -> [ImageFormatOption] {
        defaultOutputFormats(using: ffmpegRuntime())
    }

    nonisolated static func defaultOutputFormats(
        using runtime: (any FFmpegRuntime)?
    ) -> [ImageFormatOption] {
        let imageIOFormats = imageIOAvailableFormats()

        guard let runtime else {
            return imageIOFormats
        }

        let cacheKey = runtime.cacheIdentity
        return CachedValueSupport.resolve(
            readCached: { outputFormatCacheQueue.sync(execute: { defaultOutputFormatsCache[cacheKey] }) },
            storeCached: { resolved in
                outputFormatCacheQueue.sync {
                    defaultOutputFormatsCache[cacheKey] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(using: runtime) else {
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

    nonisolated private static func mergedFormats(
        primary: [ImageFormatOption],
        secondary: [ImageFormatOption]
    ) -> [ImageFormatOption] {
        ImageFormatOption.deduplicatedAndSorted(primary + secondary)
    }

    nonisolated private static func ffmpegDiscoveredFormats(from introspection: FFmpegIntrospection) -> [ImageFormatOption] {
        ImageFormatOption.deduplicatedAndSorted(
            FFmpegParsingSupport.discoveredFormats(
                from: introspection,
                makeFormat: ImageFormatOption.fromFFmpegExtension(_:muxer:)
            )
        )
    }

    nonisolated private static func imageIOAvailableFormats() -> [ImageFormatOption] {
        CachedValueSupport.resolve(
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

    nonisolated static func isFFmpegFormatSupported(
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

        let hasEncoder = format.ffmpegEncoderCandidates.contains { introspection.videoEncoders.contains($0) }
        return hasEncoder || format.allowsFFmpegAutomaticCodec
    }
}
