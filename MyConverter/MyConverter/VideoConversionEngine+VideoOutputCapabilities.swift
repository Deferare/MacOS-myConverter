import Foundation

extension VideoConversionEngine {
    nonisolated static func defaultOutputFormats() -> [VideoFormatOption] {
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

    nonisolated static func availableVideoEncoders(for format: VideoFormatOption) -> [VideoEncoderOption] {
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

            return availableEncoderOptions(
                availableEncoders: introspection.videoEncoders,
                allowsAutomatic: format.allowsFFmpegAutomaticVideoCodec,
                automaticOption: .auto,
                isCompatible: { $0.isCompatible(with: format) },
                codecCandidates: { $0.codecCandidates }
            )
        }
    }

    nonisolated static func availableAudioEncoders(for format: VideoFormatOption) -> [AudioEncoderOption] {
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

            return availableEncoderOptions(
                availableEncoders: introspection.audioEncoders,
                allowsAutomatic: format.allowsFFmpegAutomaticAudioCodec,
                automaticOption: .auto,
                isCompatible: { $0.isCompatible(with: format) },
                codecCandidates: { $0.codecCandidates }
            )
        }
    }
}
