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

    static func supportedOutputFormatsWithAVFoundation(for asset: AVURLAsset) async -> [VideoFormatOption] {
        await withTaskGroup(
            of: (Int, VideoFormatOption)?.self,
            returning: [VideoFormatOption].self
        ) { group in
            for (index, format) in VideoFormatOption.avFoundationDefaultFormats.enumerated() {
                guard let fileType = format.avFileType else { continue }
                group.addTask {
                    let isSupported = await hasCompatibleExportPreset(
                        for: asset,
                        preferredPresets: preferredExportPresets,
                        outputFileType: fileType
                    )
                    guard isSupported else { return nil }
                    return (index, format)
                }
            }

            var supported: [(Int, VideoFormatOption)] = []
            for await result in group {
                guard let result else { continue }
                supported.append(result)
            }

            return supported
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }

    static func ensureAssetReadable(_ asset: AVURLAsset) async throws {
        try await validatePlayableAsset(asset)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let hasMediaTrack = !(videoTracks.isEmpty && audioTracks.isEmpty)
        if !hasMediaTrack {
            throw ConversionError.noTracksFound
        }
    }

    static func shouldFallbackToFFmpeg(after error: Error) -> Bool {
        if let conversionError = error as? ConversionError {
            switch conversionError {
            case .invalidCustomVideoBitRate,
                    .exportCancelled,
                    .ffmpegUnavailable,
                    .ffmpegFailed:
                return false
            default:
                return true
            }
        }

        if isUnsupportedMediaFormatError(error) {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == AVFoundationErrorDomain || nsError.domain == NSOSStatusErrorDomain {
            return true
        }

        if error is AVError {
            return true
        }

        return false
    }

    static func isUnsupportedMediaFormatError(_ error: Error) -> Bool {
        if let conversionError = error as? ConversionError {
            if case let .exportFailed(underlying: underlying, _) = conversionError {
                if let underlying {
                    return isUnsupportedMediaFormatError(underlying)
                }
            }
            if case .unreadableAsset = conversionError {
                return true
            }
            if case .ffmpegFailed = conversionError {
                return false
            }
            return false
        }

        if let avError = error as? AVError {
            return avError.code == .fileFormatNotRecognized ||
                avError.code == .decoderNotFound
        }

        let nsError = error as NSError
        if nsError.domain == AVFoundationErrorDomain {
            if nsError.code == -11828 ||
                nsError.code == AVError.fileFormatNotRecognized.rawValue ||
                nsError.code == AVError.decoderNotFound.rawValue {
                return true
            }

            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                return isUnsupportedMediaFormatError(underlying)
            }

            if let dependencies = nsError.userInfo["AVErrorFailedDependenciesKey"] as? [Any],
               dependencies.contains(where: { item in
                guard let depError = item as? Error else { return false }
                return isUnsupportedMediaFormatError(depError)
            }) {
                return true
            }
        }

        if nsError.domain == NSOSStatusErrorDomain && (nsError.code == -12847 || nsError.code == -12894) {
            return true
        }

        return false
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

    private static func validatePlayableAsset(_ asset: AVURLAsset) async throws {
        let isPlayable = try await asset.load(.isPlayable)
        _ = try await asset.load(.duration)
        guard isPlayable else {
            throw ConversionError.unreadableAsset
        }
    }
}
