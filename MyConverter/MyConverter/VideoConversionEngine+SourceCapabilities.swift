import AVFoundation
import Foundation

extension VideoConversionEngine {
    private static func makeSourceCapabilityCacheKey(for inputURL: URL, runtimeIdentity: String?) -> String {
        "\(OutputPathUtilities.fileFingerprint(for: inputURL))|\(runtimeIdentity ?? "none")"
    }

    private static func makeVideoCapabilities(
        availableOutputFormats: [VideoFormatOption],
        warningMessage: String? = nil,
        errorMessage: String? = nil
    ) -> VideoSourceCapabilities {
        VideoSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )
    }

    private static func makeAudioCapabilities(
        availableOutputFormats: [AudioFormatOption],
        warningMessage: String? = nil,
        errorMessage: String? = nil
    ) -> AudioSourceCapabilities {
        AudioSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )
    }

    static func sourceCapabilitiesForAudio(for inputURL: URL) async -> AudioSourceCapabilities {
        let runtime = DefaultFFmpegRuntimeProvider().makeRuntime()
        let cacheKey = makeSourceCapabilityCacheKey(for: inputURL, runtimeIdentity: runtime?.cacheIdentity)
        return await InFlightOperationSupport.loadCachedAsyncValue(
            cacheKey: cacheKey,
            on: sourceCapabilityCacheQueue,
            cachedValue: { audioSourceCapabilitiesCache[cacheKey] },
            existingInFlight: { audioSourceCapabilitiesInFlight[cacheKey] },
            storeInFlight: { audioSourceCapabilitiesInFlight[cacheKey] = $0 },
            build: {
                let resolvedTask = Task.detached(priority: .userInitiated) {
                    await resolveAudioSourceCapabilities(for: inputURL, runtime: runtime)
                }
                return await awaitDetachedTaskValue(resolvedTask)
            },
            storeCachedValue: { audioSourceCapabilitiesCache[cacheKey] = $0 }
        )
    }

    private static func resolveAudioSourceCapabilities(
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

    static func sourceCapabilities(
        for inputURL: URL,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil
    ) async -> VideoSourceCapabilities {
        let runtime = DefaultFFmpegRuntimeProvider().makeRuntime()
        let cacheKey = makeSourceCapabilityCacheKey(for: inputURL, runtimeIdentity: runtime?.cacheIdentity)
        return await InFlightOperationSupport.loadCachedAsyncValue(
            cacheKey: cacheKey,
            on: sourceCapabilityCacheQueue,
            cachedValue: { videoSourceCapabilitiesCache[cacheKey] },
            existingInFlight: { videoSourceCapabilitiesInFlight[cacheKey] },
            storeInFlight: { videoSourceCapabilitiesInFlight[cacheKey] = $0 },
            build: {
                let resolvedTask = Task.detached(priority: .userInitiated) {
                    await resolveVideoSourceCapabilities(
                        for: inputURL,
                        runtime: runtime,
                        stagedInputLease: stagedInputLease
                    )
                }
                return await awaitDetachedTaskValue(resolvedTask)
            },
            storeCachedValue: { videoSourceCapabilitiesCache[cacheKey] = $0 }
        )
    }

    private static func resolveVideoSourceCapabilities(
        for inputURL: URL,
        runtime: (any FFmpegRuntime)?,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease?
    ) async -> VideoSourceCapabilities {
        let ffmpegAvailable = runtime != nil
        let defaultFormats = defaultOutputFormats()
        let assetTrackProbe = await assetTrackProbe(for: inputURL)

        if assetTrackProbe.isReadable {
            guard assetTrackProbe.hasVideoTrack else {
                return makeVideoCapabilities(
                    availableOutputFormats: [],
                    errorMessage: "No video track found in this source."
                )
            }

            let asset = AVURLAsset(url: inputURL)
            let avSupported = await supportedOutputFormatsWithAVFoundation(for: asset)
            if ffmpegAvailable {
                return makeVideoCapabilities(
                    availableOutputFormats: VideoFormatOption.deduplicatedAndSorted(defaultFormats + avSupported)
                )
            }

            if avSupported.isEmpty {
                return makeVideoCapabilities(
                    availableOutputFormats: [],
                    errorMessage: "No compatible output container is available for this source."
                )
            }

            return makeVideoCapabilities(availableOutputFormats: avSupported)
        }

        if let runtime {
            let hasVideoTrack = await ffmpegCanReadMappedStream(
                runtime: runtime,
                inputURL: inputURL,
                stagedInputLease: stagedInputLease,
                mapSpecifier: "0:v:0",
                frameArguments: ["-frames:v", "1"]
            )

            if !hasVideoTrack {
                return makeVideoCapabilities(
                    availableOutputFormats: [],
                    errorMessage: "No readable video track found in this source."
                )
            }

            return makeVideoCapabilities(availableOutputFormats: defaultFormats)
        }

        return makeVideoCapabilities(
            availableOutputFormats: [],
            errorMessage: "This source cannot be opened by AVFoundation and ffmpeg is unavailable."
        )
    }
}
