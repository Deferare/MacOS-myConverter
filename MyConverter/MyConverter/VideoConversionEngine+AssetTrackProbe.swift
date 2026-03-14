import AVFoundation
import Foundation

extension VideoConversionEngine {
    static func assetTrackProbe(for inputURL: URL) async -> AssetTrackProbe {
        let cacheKey = assetTrackProbeCacheKey(for: inputURL)
        return await InFlightOperationSupport.loadCachedAsyncValue(
            cacheKey: cacheKey,
            on: sourceCapabilityCacheQueue,
            cachedValue: { assetTrackProbeCache[cacheKey] },
            existingInFlight: { assetTrackProbeInFlight[cacheKey] },
            storeInFlight: { assetTrackProbeInFlight[cacheKey] = $0 },
            build: {
                await detachedTaskValue(priority: .userInitiated) {
                    await loadAssetTrackProbe(for: inputURL)
                }
            },
            storeCachedValue: { assetTrackProbeCache[cacheKey] = $0 }
        )
    }

    private static func assetTrackProbeCacheKey(for inputURL: URL) -> String {
        OutputPathUtilities.fileFingerprint(for: inputURL)
    }

    private static func loadAssetTrackProbe(for inputURL: URL) async -> AssetTrackProbe {
        let asset = AVURLAsset(url: inputURL)

        do {
            try await validatePlayableAsset(asset)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            return AssetTrackProbe(
                isReadable: true,
                hasVideoTrack: !videoTracks.isEmpty,
                hasAudioTrack: !audioTracks.isEmpty
            )
        } catch {
            return AssetTrackProbe(
                isReadable: false,
                hasVideoTrack: false,
                hasAudioTrack: false
            )
        }
    }
}
