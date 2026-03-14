import AVFoundation
import Foundation

extension VideoConversionEngine {
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

            let created = InFlightContinuation<[String]>()
            exportPresetCompatibilityInFlight[cacheKey] = created
            return (created, true)
        }

        if !shouldBuild {
            return await InFlightOperationSupport.awaitContinuation(
                inFlight,
                on: exportPresetCompatibilityCacheQueue
            )
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

        var availabilityInFlight: InFlightContinuation<Bool>?
        _ = InFlightOperationSupport.finishContinuation(
            presets,
            in: inFlight,
            on: exportPresetCompatibilityCacheQueue
        ) {
            exportPresetCompatibilityCache[cacheKey] = presets
            exportPresetAvailabilityCache[cacheKey] = !presets.isEmpty
            availabilityInFlight = exportPresetAvailabilityInFlight[cacheKey]
            exportPresetCompatibilityInFlight[cacheKey] = nil
            exportPresetAvailabilityInFlight[cacheKey] = nil
        }

        if let availabilityInFlight {
            InFlightOperationSupport.finishContinuation(
                !presets.isEmpty,
                in: availabilityInFlight,
                on: exportPresetCompatibilityCacheQueue
            ) {}
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
            let presets = await InFlightOperationSupport.awaitContinuation(
                inFlight,
                on: exportPresetCompatibilityCacheQueue
            )
            return !presets.isEmpty
        }

        let (inFlight, shouldBuild) = exportPresetCompatibilityCacheQueue.sync {
            if let existing = exportPresetAvailabilityInFlight[cacheKey] {
                return (existing, false)
            }

            let created = InFlightContinuation<Bool>()
            exportPresetAvailabilityInFlight[cacheKey] = created
            return (created, true)
        }

        if !shouldBuild {
            return await InFlightOperationSupport.awaitContinuation(
                inFlight,
                on: exportPresetCompatibilityCacheQueue
            )
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

        return InFlightOperationSupport.finishContinuation(
            isCompatible,
            in: inFlight,
            on: exportPresetCompatibilityCacheQueue
        ) {
            exportPresetAvailabilityCache[cacheKey] = isCompatible
            exportPresetAvailabilityInFlight[cacheKey] = nil
        }
    }

    static func exportPresetCompatibilityCacheKey(
        for inputURL: URL,
        outputFileType: AVFileType
    ) -> String {
        "\(OutputPathUtilities.fileFingerprint(for: inputURL))|\(outputFileType.rawValue)"
    }
}
