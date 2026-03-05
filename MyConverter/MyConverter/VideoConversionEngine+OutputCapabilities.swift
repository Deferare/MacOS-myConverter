import Foundation

extension VideoConversionEngine {
    static func defaultOutputFormats() -> [VideoFormatOption] {
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

    static func availableVideoEncoders(for format: VideoFormatOption) -> [VideoEncoderOption] {
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

            let explicitOptions = VideoEncoderOption.allCases.filter { option in
                guard option != .auto else { return false }
                return option.isCompatible(with: format) &&
                    option.codecCandidates.contains(where: { introspection.videoEncoders.contains($0) })
            }

            return resolvedEncoderOptions(
                explicitOptions: explicitOptions,
                allowsAutomatic: format.allowsFFmpegAutomaticVideoCodec,
                automaticOption: .auto
            )
        }
    }

    static func availableAudioEncoders(for format: VideoFormatOption) -> [AudioEncoderOption] {
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
