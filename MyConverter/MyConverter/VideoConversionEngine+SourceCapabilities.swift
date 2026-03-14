import AVFoundation
import Foundation

extension VideoConversionEngine {
    static func sourceCapabilities(
        for inputURL: URL,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil
    ) async -> VideoSourceCapabilities {
        let runtime = ffmpegRuntime()
        let cacheKey = makeSourceCapabilityCacheKey(for: inputURL, runtimeIdentity: runtime?.cacheIdentity)
        return await InFlightOperationSupport.loadCachedAsyncValue(
            cacheKey: cacheKey,
            on: sourceCapabilityCacheQueue,
            cachedValue: { videoSourceCapabilitiesCache[cacheKey] },
            existingInFlight: { videoSourceCapabilitiesInFlight[cacheKey] },
            storeInFlight: { videoSourceCapabilitiesInFlight[cacheKey] = $0 },
            build: {
                await detachedTaskValue(priority: .userInitiated) {
                    await resolveVideoSourceCapabilities(
                        for: inputURL,
                        runtime: runtime,
                        stagedInputLease: stagedInputLease
                    )
                }
            },
            storeCachedValue: { videoSourceCapabilitiesCache[cacheKey] = $0 }
        )
    }

    static func resolveVideoSourceCapabilities(
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
