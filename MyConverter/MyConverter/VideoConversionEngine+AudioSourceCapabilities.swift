import Foundation

extension VideoConversionEngine {
    static func sourceCapabilitiesForAudio(for inputURL: URL) async -> AudioSourceCapabilities {
        let runtime = ffmpegRuntime()
        let cacheKey = makeSourceCapabilityCacheKey(for: inputURL, runtimeIdentity: runtime?.cacheIdentity)
        return await InFlightOperationSupport.loadCachedAsyncValue(
            cacheKey: cacheKey,
            on: sourceCapabilityCacheQueue,
            cachedValue: { audioSourceCapabilitiesCache[cacheKey] },
            existingInFlight: { audioSourceCapabilitiesInFlight[cacheKey] },
            storeInFlight: { audioSourceCapabilitiesInFlight[cacheKey] = $0 },
            build: {
                await detachedTaskValue(priority: .userInitiated) {
                    await resolveAudioSourceCapabilities(for: inputURL, runtime: runtime)
                }
            },
            storeCachedValue: { audioSourceCapabilitiesCache[cacheKey] = $0 }
        )
    }

    static func resolveAudioSourceCapabilities(
        for inputURL: URL,
        runtime: (any FFmpegRuntime)?
    ) async -> AudioSourceCapabilities {
        guard let runtime else {
            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "Audio conversion requires ffmpeg, but ffmpeg was not found."
            )
        }

        let defaultFormats = defaultAudioOutputFormats()
        guard !defaultFormats.isEmpty else {
            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "No compatible audio output format is available with the current ffmpeg build."
            )
        }

        let assetTrackProbe = await assetTrackProbe(for: inputURL)
        if assetTrackProbe.isReadable {
            if assetTrackProbe.hasAudioTrack {
                return makeAudioCapabilities(availableOutputFormats: defaultFormats)
            }

            return makeAudioCapabilities(
                availableOutputFormats: [],
                errorMessage: "No audio track found in this source."
            )
        }

        let hasAudioTrack = await ffmpegCanReadMappedStream(
            runtime: runtime,
            inputURL: inputURL,
            mapSpecifier: "0:a:0",
            frameArguments: ["-frames:a", "1"]
        )

        if hasAudioTrack {
            return makeAudioCapabilities(availableOutputFormats: defaultFormats)
        }

        return makeAudioCapabilities(
            availableOutputFormats: [],
            errorMessage: "No readable audio track found in this source."
        )
    }
}
