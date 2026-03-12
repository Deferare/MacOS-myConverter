import AVFoundation
import Foundation

extension ContentViewModel {
    struct BatchExecutionEnvironment: Sendable {
        let videoFFmpegContext: FFmpegExecutionContext?
        let imageFFmpegContext: FFmpegExecutionContext?
        let preparedVideoSources: [String: VideoConversionEngine.PreparedSourceContext]
        let preparedAudioCapabilities: [String: AudioSourceCapabilities]
        let preparedImageCapabilities: [String: ImageSourceCapabilities]
    }

    nonisolated static func collectPreparedSourceValues<Value: Sendable>(
        from preparedSources: [PreparedSourceConversion],
        buildValue: @escaping @Sendable (PreparedSourceConversion) async -> Value
    ) async -> [String: Value] {
        await withTaskGroup(
            of: (String, Value)?.self,
            returning: [String: Value].self
        ) { group in
            for preparedSource in preparedSources {
                group.addTask {
                    await SecurityScopedResourceAccess.withAccess(to: preparedSource.sourceURL) {
                        let value = await buildValue(preparedSource)
                        return (preparedSource.sourceID, value)
                    }
                }
            }

            var prepared: [String: Value] = [:]
            for await result in group {
                guard let (sourceID, value) = result else { continue }
                prepared[sourceID] = value
            }
            return prepared
        }
    }

    nonisolated static func prepareVideoBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        outputSettings: VideoOutputSettings,
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = VideoConversionEngine.makeFFmpegExecutionContext(using: runtimeProvider)
        let outputFileType = outputSettings.containerFormat.avFileType
        let preparedVideoSources = await collectPreparedSourceValues(from: preparedSources) { preparedSource in
            let sourceCapabilities = await VideoConversionEngine.sourceCapabilities(
                for: preparedSource.sourceURL
            )
            let assetTrackProbe = await VideoConversionEngine.assetTrackProbe(
                for: preparedSource.sourceURL
            )

            let candidatePresets: [String]?
            if let outputFileType,
               assetTrackProbe.isReadable,
               assetTrackProbe.hasVideoTrack {
                let asset = AVURLAsset(url: preparedSource.sourceURL)
                candidatePresets = await VideoConversionEngine.compatibleExportPresets(
                    for: asset,
                    preferredPresets: VideoConversionEngine.preferredExportPresets,
                    outputFileType: outputFileType
                )
            } else {
                candidatePresets = nil
            }

            return VideoConversionEngine.PreparedSourceContext(
                sourceCapabilities: sourceCapabilities,
                assetTrackProbe: assetTrackProbe,
                candidatePresets: candidatePresets,
                stagedInputLease: nil
            )
        }

        return BatchExecutionEnvironment(
            videoFFmpegContext: ffmpegContext,
            imageFFmpegContext: nil,
            preparedVideoSources: preparedVideoSources,
            preparedAudioCapabilities: [:],
            preparedImageCapabilities: [:]
        )
    }

    func prepareSingleVideoBatchExecutionEnvironment(
        preparedSource: PreparedSourceConversion,
        outputSettings _: VideoOutputSettings
    ) async -> BatchExecutionEnvironment {
        let preparedContext: VideoConversionEngine.PreparedSourceContext
        if let preparedSelection = await prepareSelectedSingleVideoSelectionIfNeeded(
            for: preparedSource.sourceURL
        ) {
            preparedContext = preparedSelection.preparedSourceContext
        } else {
            let assetTrackProbe = await VideoConversionEngine.assetTrackProbe(for: preparedSource.sourceURL)
            let sourceCapabilities = await VideoConversionEngine.sourceCapabilities(for: preparedSource.sourceURL)
            preparedContext = VideoConversionEngine.PreparedSourceContext(
                sourceCapabilities: sourceCapabilities,
                assetTrackProbe: assetTrackProbe,
                candidatePresets: nil,
                stagedInputLease: nil
            )
        }

        return BatchExecutionEnvironment(
            videoFFmpegContext: VideoConversionEngine.makeFFmpegExecutionContext(
                using: services.ffmpegRuntimeProvider
            ),
            imageFFmpegContext: nil,
            preparedVideoSources: [preparedSource.sourceID: preparedContext],
            preparedAudioCapabilities: [:],
            preparedImageCapabilities: [:]
        )
    }

    nonisolated static func prepareAudioBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = VideoConversionEngine.makeFFmpegExecutionContext(using: runtimeProvider)
        let preparedAudioCapabilities = await collectPreparedSourceValues(from: preparedSources) {
            preparedSource in
            await VideoConversionEngine.sourceCapabilitiesForAudio(
                for: preparedSource.sourceURL
            )
        }

        return BatchExecutionEnvironment(
            videoFFmpegContext: ffmpegContext,
            imageFFmpegContext: nil,
            preparedVideoSources: [:],
            preparedAudioCapabilities: preparedAudioCapabilities,
            preparedImageCapabilities: [:]
        )
    }

    nonisolated static func prepareImageBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = ImageConversionEngine.makeFFmpegExecutionContext(using: runtimeProvider)
        let preparedImageCapabilities = await collectPreparedSourceValues(from: preparedSources) {
            preparedSource in
            await ImageConversionEngine.sourceCapabilities(
                for: preparedSource.sourceURL
            )
        }

        return BatchExecutionEnvironment(
            videoFFmpegContext: nil,
            imageFFmpegContext: ffmpegContext,
            preparedVideoSources: [:],
            preparedAudioCapabilities: [:],
            preparedImageCapabilities: preparedImageCapabilities
        )
    }
}
