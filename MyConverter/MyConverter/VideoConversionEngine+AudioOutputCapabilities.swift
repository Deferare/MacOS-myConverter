import Foundation

extension VideoConversionEngine {
    static func defaultAudioOutputFormats() -> [AudioFormatOption] {
        let knownFormats = AudioFormatOption.ffmpegKnownFormats

        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return knownFormats
        }

        return cachedCapabilityValue(
            readCached: { capabilityCacheQueue.sync(execute: { defaultAudioFormatsCache[ffmpegPath] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    defaultAudioFormatsCache[ffmpegPath] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
                return knownFormats
            }

            let discovered = ffmpegDiscoveredAudioFormats(from: introspection)
            let candidates = AudioFormatOption.deduplicatedAndSorted(knownFormats + discovered)
            return candidates.filter { isFFmpegAudioFormatSupported($0, introspection: introspection) }
        }
    }

    static func availableAudioEncoders(for format: AudioFormatOption) -> [AudioEncoderOption] {
        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return format.allowsFFmpegAutomaticAudioCodec ? [.auto] : []
        }

        let cacheKey = makeCapabilityCacheKey(path: ffmpegPath, normalizedID: format.normalizedID)
        return cachedCapabilityValue(
            readCached: { capabilityCacheQueue.sync(execute: { audioFormatEncoderOptionsCache[cacheKey] }) },
            storeCached: { resolved in
                capabilityCacheQueue.sync {
                    audioFormatEncoderOptionsCache[cacheKey] = resolved
                }
            }
        ) {
            guard let introspection = try? inspectFFmpeg(at: ffmpegPath),
                  isFFmpegAudioFormatSupported(format, introspection: introspection) else {
                return []
            }

            let explicitOptions = AudioEncoderOption.allCases.filter { option in
                guard option != .auto else { return false }
                return option.isCompatible(with: format) &&
                    option.codecCandidates.contains(where: { introspection.audioEncoders.contains($0) })
            }

            return resolvedEncoderOptions(
                explicitOptions: explicitOptions,
                allowsAutomatic: format.allowsFFmpegAutomaticAudioCodec,
                automaticOption: .auto
            )
        }
    }
}
