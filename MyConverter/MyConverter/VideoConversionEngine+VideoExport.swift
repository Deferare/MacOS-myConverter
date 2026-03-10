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
                onProgress: onProgress
            )
        }

        if let converted = try await attemptFFmpegConversion(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds,
            ffmpegContext: ffmpegContext,
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
                ffmpegContext: ffmpegContext,
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
        for asset: AVURLAsset,
        preferredPresets: [String],
        outputFileType: AVFileType
    ) async -> [String] {
        let cacheKey = exportPresetCompatibilityCacheKey(for: asset.url, outputFileType: outputFileType)
        if let cached = exportPresetCompatibilityCacheQueue.sync(execute: { exportPresetCompatibilityCache[cacheKey] }) {
            return cached
        }

        let (inFlight, shouldBuild) = exportPresetCompatibilityCacheQueue.sync {
            if let existing = exportPresetCompatibilityInFlight[cacheKey] {
                return (existing, false)
            }

            let created = InFlightCapability<[String]>()
            exportPresetCompatibilityInFlight[cacheKey] = created
            return (created, true)
        }

        if !shouldBuild {
            return await awaitCompatibleExportPresets(inFlight)
        }

        let presets = await withTaskGroup(
            of: (Int, String)?.self,
            returning: [String].self
        ) { group in
            for (index, preset) in preferredPresets.enumerated() {
                group.addTask {
                    let isCompatible = await AVAssetExportSession.compatibility(
                        ofExportPreset: preset,
                        with: asset,
                        outputFileType: outputFileType
                    )
                    guard isCompatible else { return nil }
                    return (index, preset)
                }
            }

            var compatible: [(Int, String)] = []
            for await result in group {
                guard let result else { continue }
                compatible.append(result)
            }

            return compatible
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }

        var continuations: [CheckedContinuation<[String], Never>] = []
        var availabilityContinuations: [CheckedContinuation<Bool, Never>] = []
        exportPresetCompatibilityCacheQueue.sync {
            exportPresetCompatibilityCache[cacheKey] = presets
            exportPresetAvailabilityCache[cacheKey] = !presets.isEmpty
            inFlight.result = presets
            continuations = inFlight.continuations
            inFlight.continuations.removeAll()
            exportPresetCompatibilityInFlight[cacheKey] = nil

            if let availabilityInFlight = exportPresetAvailabilityInFlight[cacheKey] {
                availabilityInFlight.result = !presets.isEmpty
                availabilityContinuations = availabilityInFlight.continuations
                availabilityInFlight.continuations.removeAll()
                exportPresetAvailabilityInFlight[cacheKey] = nil
            }
        }
        for continuation in continuations {
            continuation.resume(returning: presets)
        }
        for continuation in availabilityContinuations {
            continuation.resume(returning: !presets.isEmpty)
        }
        return presets
    }

    static func hasCompatibleExportPreset(
        for asset: AVURLAsset,
        preferredPresets: [String],
        outputFileType: AVFileType
    ) async -> Bool {
        let cacheKey = exportPresetCompatibilityCacheKey(for: asset.url, outputFileType: outputFileType)
        if let cached = exportPresetCompatibilityCacheQueue.sync(execute: { exportPresetAvailabilityCache[cacheKey] }) {
            return cached
        }
        if let cached = exportPresetCompatibilityCacheQueue.sync(execute: { exportPresetCompatibilityCache[cacheKey] }) {
            return !cached.isEmpty
        }

        if let inFlight = exportPresetCompatibilityCacheQueue.sync(execute: { exportPresetCompatibilityInFlight[cacheKey] }) {
            let presets = await awaitCompatibleExportPresets(inFlight)
            return !presets.isEmpty
        }

        let (inFlight, shouldBuild) = exportPresetCompatibilityCacheQueue.sync {
            if let existing = exportPresetAvailabilityInFlight[cacheKey] {
                return (existing, false)
            }

            let created = InFlightCapability<Bool>()
            exportPresetAvailabilityInFlight[cacheKey] = created
            return (created, true)
        }

        if !shouldBuild {
            return await awaitCompatibleExportPresetAvailability(inFlight)
        }

        var isCompatible = false
        for preset in preferredPresets {
            isCompatible = await AVAssetExportSession.compatibility(
                ofExportPreset: preset,
                with: asset,
                outputFileType: outputFileType
            )
            if isCompatible {
                break
            }
        }

        var continuations: [CheckedContinuation<Bool, Never>] = []
        exportPresetCompatibilityCacheQueue.sync {
            exportPresetAvailabilityCache[cacheKey] = isCompatible
            inFlight.result = isCompatible
            continuations = inFlight.continuations
            inFlight.continuations.removeAll()
            exportPresetAvailabilityInFlight[cacheKey] = nil
        }
        for continuation in continuations {
            continuation.resume(returning: isCompatible)
        }
        return isCompatible
    }

    private static func awaitCompatibleExportPresets(
        _ inFlight: InFlightCapability<[String]>
    ) async -> [String] {
        await withCheckedContinuation { continuation in
            var resolved: [String]?

            exportPresetCompatibilityCacheQueue.sync {
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

    private static func awaitCompatibleExportPresetAvailability(
        _ inFlight: InFlightCapability<Bool>
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            var resolved: Bool?

            exportPresetCompatibilityCacheQueue.sync {
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

    private static func exportPresetCompatibilityCacheKey(
        for inputURL: URL,
        outputFileType: AVFileType
    ) -> String {
        "\(OutputPathUtilities.fileFingerprint(for: inputURL))|\(outputFileType.rawValue)"
    }

    private static func export(
        _ session: AVAssetExportSession,
        to outputURL: URL,
        as outputFileType: AVFileType,
        preset: String,
        onProgress: @escaping ProgressHandler
    ) async throws {
        await onProgress(0)
        let token = PerformanceSignpost.begin("VideoEncode", message: preset)

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
            PerformanceSignpost.end("VideoEncode", token: token, message: preset)
            await onProgress(1)
        } catch is CancellationError {
            PerformanceSignpost.end("VideoEncode", token: token, message: "cancelled")
            throw ConversionError.exportCancelled
        } catch {
            PerformanceSignpost.end("VideoEncode", token: token, message: "failed")
            throw ConversionError.exportFailed(underlying: error, preset: preset)
        }
    }
}
