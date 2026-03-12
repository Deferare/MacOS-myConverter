import Foundation

extension VideoConversionEngine {
    nonisolated static func defaultAudioOutputFormats() -> [AudioFormatOption] {
        let knownFormats = AudioFormatOption.ffmpegKnownFormats

        guard let runtime = ffmpegRuntime() else {
            return knownFormats
        }

        return CachedValueSupport.resolve(
            readCached: { capabilityCacheQueue.sync(execute: { defaultAudioFormatsCache[runtime.cacheIdentity] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    defaultAudioFormatsCache[runtime.cacheIdentity] = resolved
                }
            }
        ) {
            guard let introspection = ffmpegIntrospection(using: runtime) else {
                return knownFormats
            }

            let discovered = ffmpegDiscoveredAudioFormats(from: introspection)
            let candidates = AudioFormatOption.deduplicatedAndSorted(knownFormats + discovered)
            return candidates.filter { isFFmpegAudioFormatSupported($0, introspection: introspection) }
        }
    }

    nonisolated static func availableAudioEncoders(for format: AudioFormatOption) -> [AudioEncoderOption] {
        guard let runtime = ffmpegRuntime() else {
            return automaticOptionIfEnabled(.auto, enabled: format.allowsFFmpegAutomaticAudioCodec)
        }

        let cacheKey = makeCapabilityCacheKey(path: runtime.cacheIdentity, normalizedID: format.normalizedID)
        return CachedValueSupport.resolve(
            readCached: { capabilityCacheQueue.sync(execute: { audioFormatEncoderOptionsCache[cacheKey] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    audioFormatEncoderOptionsCache[cacheKey] = resolved
                }
            }
        ) {
            guard let introspection = supportedIntrospection(using: runtime, for: format) else {
                return []
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
