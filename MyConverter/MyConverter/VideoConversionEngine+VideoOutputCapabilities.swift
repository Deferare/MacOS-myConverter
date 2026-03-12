import Foundation

extension VideoConversionEngine {
    nonisolated static func defaultOutputFormats() -> [VideoFormatOption] {
        let avFormats = VideoFormatOption.avFoundationDefaultFormats

        guard let runtime = DefaultFFmpegRuntimeProvider().makeRuntime() else {
            return avFormats
        }

        return CachedValueSupport.resolve(
            readCached: { capabilityCacheQueue.sync(execute: { defaultVideoFormatsCache[runtime.cacheIdentity] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    defaultVideoFormatsCache[runtime.cacheIdentity] = resolved
                }
            }
        ) {
            guard let introspection = ffmpegIntrospection(using: runtime) else {
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

        guard let runtime = DefaultFFmpegRuntimeProvider().makeRuntime() else {
            return automaticOptionIfEnabled(.auto, enabled: true)
        }

        let cacheKey = makeCapabilityCacheKey(path: runtime.cacheIdentity, normalizedID: format.normalizedID)
        return CachedValueSupport.resolve(
            readCached: { capabilityCacheQueue.sync(execute: { videoEncoderOptionsCache[cacheKey] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    videoEncoderOptionsCache[cacheKey] = resolved
                }
            }
        ) {
            guard let introspection = supportedIntrospection(using: runtime, for: format) else {
                return automaticOptionIfEnabled(.auto, enabled: format.avFileType != nil)
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

        guard let runtime = DefaultFFmpegRuntimeProvider().makeRuntime() else {
            return automaticOptionIfEnabled(.auto, enabled: true)
        }

        let cacheKey = makeCapabilityCacheKey(path: runtime.cacheIdentity, normalizedID: format.normalizedID)
        return CachedValueSupport.resolve(
            readCached: { capabilityCacheQueue.sync(execute: { videoFormatAudioEncoderOptionsCache[cacheKey] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    videoFormatAudioEncoderOptionsCache[cacheKey] = resolved
                }
            }
        ) {
            guard let introspection = supportedIntrospection(using: runtime, for: format) else {
                return automaticOptionIfEnabled(.auto, enabled: format.avFileType != nil)
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
