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

    static func compatibleExportPresets(
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
