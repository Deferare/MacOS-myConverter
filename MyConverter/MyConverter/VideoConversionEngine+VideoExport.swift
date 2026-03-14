import AVFoundation
import Foundation

extension VideoConversionEngine {
    static func convert(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?,
        ffmpegContext: FFmpegExecutionContext? = nil,
        preparedSourceContext: PreparedSourceContext? = nil,
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
                ffmpegContext: ffmpegContext,
                stagedInputLease: preparedSourceContext?.stagedInputLease,
                onProgress: onProgress
            )
        }

        if let converted = try await attemptFFmpegConversion(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            ffmpegContext: ffmpegContext,
            stagedInputLease: preparedSourceContext?.stagedInputLease,
            onProgress: onProgress
        ) {
            return converted
        }

        let asset = AVURLAsset(url: inputURL)
        if let preparedSourceContext {
            guard preparedSourceContext.assetTrackProbe.isReadable else {
                return try await attemptFFmpegConversionOrThrowUnavailable(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: inputDurationSeconds,
                    ffmpegContext: ffmpegContext,
                    stagedInputLease: preparedSourceContext.stagedInputLease,
                    onProgress: onProgress
                )
            }
        } else {
            do {
                try await ensureAssetReadable(asset)
            } catch {
                if isUnsupportedMediaFormatError(error) {
                    return try await attemptFFmpegConversionOrThrowUnavailable(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        outputSettings: outputSettings,
                        inputDurationSeconds: inputDurationSeconds,
                        ffmpegContext: ffmpegContext,
                        onProgress: onProgress
                    )
                }
                throw error
            }
        }

        guard let outputFileType else {
            throw ConversionError.unsupportedOutputType(outputSettings.containerFormat)
        }

        let candidatePresets: [String]
        if let preparedCandidatePresets = preparedSourceContext?.candidatePresets {
            candidatePresets = preparedCandidatePresets
        } else {
            candidatePresets = await compatibleExportPresets(
                for: asset,
                preferredPresets: preferredExportPresets,
                outputFileType: outputFileType
            )
        }

        guard !candidatePresets.isEmpty else {
            return try await attemptFFmpegConversionOrThrowUnavailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds,
                ffmpegContext: ffmpegContext,
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
            } catch {
                try rethrowIfExportCancelled(error)
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
                ffmpegContext: ffmpegContext,
                stagedInputLease: preparedSourceContext?.stagedInputLease,
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
}
