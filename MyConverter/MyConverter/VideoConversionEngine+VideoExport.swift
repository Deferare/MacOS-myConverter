import AVFoundation
import Foundation

extension VideoConversionEngine {
    static func convert(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)
        let outputFileType = outputSettings.containerFormat.avFileType

        if outputFileType == nil {
            return try await attemptFFmpegConversionOrThrowUnavailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                onProgress: onProgress
            )
        }

        if let converted = try await attemptFFmpegConversion(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            onProgress: onProgress
        ) {
            return converted
        }

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetReadable(asset)
        } catch {
            if isUnsupportedMediaFormatError(error) {
                return try await attemptFFmpegConversionOrThrowUnavailable(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: inputDurationSeconds,
                    onProgress: onProgress
                )
            }
            throw error
        }

        guard let outputFileType else {
            throw ConversionError.unsupportedOutputType(outputSettings.containerFormat)
        }

        let candidatePresets = await compatibleExportPresets(
            for: asset,
            preferredPresets: preferredExportPresets,
            outputFileType: outputFileType
        )

        guard !candidatePresets.isEmpty else {
            return try await attemptFFmpegConversionOrThrowUnavailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                onProgress: onProgress
            )
        }

        var lastError: Error?
        for preset in candidatePresets {
            guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
                lastError = ConversionError.cannotCreateExportSession(preset)
                continue
            }

            guard session.supportedFileTypes.contains(outputFileType) else {
                lastError = ConversionError.unsupportedOutputType(outputSettings.containerFormat)
                continue
            }

            session.shouldOptimizeForNetworkUse = true

            do {
                try await export(
                    session,
                    to: outputURL,
                    as: outputFileType,
                    preset: preset,
                    onProgress: onProgress
                )
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    return outputURL
                }
                lastError = ConversionError.exportFailed(
                    underlying: nil,
                    preset: preset
                )
            } catch is CancellationError {
                throw ConversionError.exportCancelled
            } catch ConversionError.exportCancelled {
                throw ConversionError.exportCancelled
            } catch {
                lastError = error
                if isUnsupportedMediaFormatError(error) {
                    break
                }
            }
        }

        if let lastError, shouldFallbackToFFmpeg(after: lastError) {
            if let converted = try await attemptFFmpegConversion(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                onProgress: onProgress
            ) {
                return converted
            }

            if isUnsupportedMediaFormatError(lastError) {
                throw ConversionError.ffmpegUnavailable
            }
        }

        throw lastError ?? ConversionError.unsupportedSource
    }

    static func supportedOutputFormatsWithAVFoundation(for asset: AVAsset) async -> [VideoFormatOption] {
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

    private static func compatibleExportPresets(
        for asset: AVAsset,
        preferredPresets: [String],
        outputFileType: AVFileType
    ) async -> [String] {
        var presets: [String] = []
        for preset in preferredPresets {
            let isCompatible = await AVAssetExportSession.compatibility(
                ofExportPreset: preset,
                with: asset,
                outputFileType: outputFileType
            )
            if isCompatible {
                presets.append(preset)
            }
        }
        return presets
    }

    private static func export(
        _ session: AVAssetExportSession,
        to outputURL: URL,
        as outputFileType: AVFileType,
        preset: String,
        onProgress: @escaping ProgressHandler
    ) async throws {
        await onProgress(0)

        let progressTask = Task {
            for await state in session.states(updateInterval: 0.15) {
                if Task.isCancelled {
                    break
                }

                switch state {
                case .pending, .waiting:
                    break
                case .exporting(let progress):
                    let fractionCompleted = min(max(progress.fractionCompleted, 0), 1)
                    await onProgress(fractionCompleted)
                @unknown default:
                    break
                }
            }
        }
        defer {
            progressTask.cancel()
        }

        do {
            try await session.export(to: outputURL, as: outputFileType)
            await onProgress(1)
        } catch is CancellationError {
            throw ConversionError.exportCancelled
        } catch {
            throw ConversionError.exportFailed(underlying: error, preset: preset)
        }
    }
}
