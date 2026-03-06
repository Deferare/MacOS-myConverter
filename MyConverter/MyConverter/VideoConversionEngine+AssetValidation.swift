import AVFoundation
import Foundation

extension VideoConversionEngine {
    static func assetTrackProbe(for inputURL: URL) async -> AssetTrackProbe {
        let cacheKey = assetTrackProbeCacheKey(for: inputURL)
        if let cached = sourceCapabilityCacheQueue.sync(execute: { assetTrackProbeCache[cacheKey] }) {
            return cached
        }

        let (inFlight, shouldBuild) = sourceCapabilityCacheQueue.sync {
            if let existing = assetTrackProbeInFlight[cacheKey] {
                return (existing, false)
            }

            let created = InFlightCapability<AssetTrackProbe>()
            assetTrackProbeInFlight[cacheKey] = created
            return (created, true)
        }

        if !shouldBuild {
            return await awaitAssetTrackProbe(inFlight)
        }

        let resolved = await Task.detached(priority: .userInitiated) {
            await loadAssetTrackProbe(for: inputURL)
        }.value

        var continuations: [CheckedContinuation<AssetTrackProbe, Never>] = []
        sourceCapabilityCacheQueue.sync {
            assetTrackProbeCache[cacheKey] = resolved
            inFlight.result = resolved
            continuations = inFlight.continuations
            inFlight.continuations.removeAll()
            assetTrackProbeInFlight[cacheKey] = nil
        }
        for continuation in continuations {
            continuation.resume(returning: resolved)
        }
        return resolved
    }

    static func supportedOutputFormatsWithAVFoundation(for asset: AVURLAsset) async -> [VideoFormatOption] {
        var supported: [VideoFormatOption] = []
        for format in VideoFormatOption.avFoundationDefaultFormats {
            guard let fileType = format.avFileType else { continue }
            let presets = await compatibleExportPresets(
                for: asset,
                preferredPresets: preferredExportPresets,
                outputFileType: fileType
            )
            if !presets.isEmpty {
                supported.append(format)
            }
        }
        return supported
    }

    static func ensureAssetHasVideoTrack(_ asset: AVURLAsset) async throws {
        try await ensureAssetHasTrack(
            asset,
            mediaType: .video,
            missingTrackError: .noVideoTrackFound
        )
    }

    static func ensureAssetHasAudioTrack(_ asset: AVURLAsset) async throws {
        try await ensureAssetHasTrack(
            asset,
            mediaType: .audio,
            missingTrackError: .noTracksFound
        )
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
        let standardizedURL = inputURL.standardizedFileURL
        let resourceValues = try? standardizedURL.resourceValues(
            forKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        let fileSize = resourceValues?.fileSize ?? -1
        let modificationInterval = resourceValues?.contentModificationDate?.timeIntervalSinceReferenceDate ?? -1
        return "\(standardizedURL.path)|\(fileSize)|\(modificationInterval)"
    }

    private static func awaitAssetTrackProbe(
        _ inFlight: InFlightCapability<AssetTrackProbe>
    ) async -> AssetTrackProbe {
        await withCheckedContinuation { continuation in
            var resolved: AssetTrackProbe?

            sourceCapabilityCacheQueue.sync {
                if let result = inFlight.result {
                    resolved = result
                } else {
                    inFlight.continuations.append(continuation)
                }
            }

            if let resolved {
                continuation.resume(returning: resolved)
            }
        }
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

    private static func ensureAssetHasTrack(
        _ asset: AVURLAsset,
        mediaType: AVMediaType,
        missingTrackError: ConversionError
    ) async throws {
        try await validatePlayableAsset(asset)
        let tracks = try await asset.loadTracks(withMediaType: mediaType)
        if tracks.isEmpty {
            throw missingTrackError
        }
    }
}
