import AVFoundation
import Foundation

extension ContentViewModel {
    struct BatchExecutionEnvironment: Sendable {
        let videoFFmpegContext: FFmpegExecutionContext?
        let imageFFmpegContext: FFmpegExecutionContext?
        let preparedVideoSources: [String: VideoConversionEngine.PreparedSourceContext]
        let preparedAudioCapabilities: [String: AudioSourceCapabilities]
        let preparedImageCapabilities: [String: ImageSourceCapabilities]

        nonisolated static func video(
            ffmpegContext: FFmpegExecutionContext?,
            preparedVideoSources: [String: VideoConversionEngine.PreparedSourceContext]
        ) -> Self {
            BatchExecutionEnvironment(
                videoFFmpegContext: ffmpegContext,
                imageFFmpegContext: nil,
                preparedVideoSources: preparedVideoSources,
                preparedAudioCapabilities: [:],
                preparedImageCapabilities: [:]
            )
        }

        nonisolated static func audio(
            ffmpegContext: FFmpegExecutionContext?,
            preparedAudioCapabilities: [String: AudioSourceCapabilities]
        ) -> Self {
            BatchExecutionEnvironment(
                videoFFmpegContext: ffmpegContext,
                imageFFmpegContext: nil,
                preparedVideoSources: [:],
                preparedAudioCapabilities: preparedAudioCapabilities,
                preparedImageCapabilities: [:]
            )
        }

        nonisolated static func image(
            ffmpegContext: FFmpegExecutionContext?,
            preparedImageCapabilities: [String: ImageSourceCapabilities]
        ) -> Self {
            BatchExecutionEnvironment(
                videoFFmpegContext: nil,
                imageFFmpegContext: ffmpegContext,
                preparedVideoSources: [:],
                preparedAudioCapabilities: [:],
                preparedImageCapabilities: preparedImageCapabilities
            )
        }
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

    nonisolated static func prepareVideoSourceContext(
        for sourceURL: URL,
        outputFileType: AVFileType?,
        stagedInputLease: FFmpegStagingSupport.StagedInputLease? = nil,
        assetTrackProbe: VideoConversionEngine.AssetTrackProbe? = nil
    ) async -> VideoConversionEngine.PreparedSourceContext {
        let resolvedAssetTrackProbe: VideoConversionEngine.AssetTrackProbe
        if let assetTrackProbe {
            resolvedAssetTrackProbe = assetTrackProbe
        } else {
            resolvedAssetTrackProbe = await VideoConversionEngine.assetTrackProbe(
                for: sourceURL
            )
        }
        let sourceCapabilities = await VideoConversionEngine.sourceCapabilities(
            for: sourceURL,
            stagedInputLease: stagedInputLease
        )

        let candidatePresets: [String]?
        if let outputFileType,
           resolvedAssetTrackProbe.isReadable,
           resolvedAssetTrackProbe.hasVideoTrack {
            let asset = AVURLAsset(url: sourceURL)
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
            assetTrackProbe: resolvedAssetTrackProbe,
            candidatePresets: candidatePresets,
            stagedInputLease: stagedInputLease
        )
    }

    nonisolated static func prepareVideoBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        outputSettings: VideoOutputSettings,
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = VideoConversionEngine.makeFFmpegExecutionContext(using: runtimeProvider)
        let outputFileType = outputSettings.containerFormat.avFileType
        let preparedVideoSources = await collectPreparedSourceValues(from: preparedSources) { preparedSource in
            await prepareVideoSourceContext(
                for: preparedSource.sourceURL,
                outputFileType: outputFileType
            )
        }

        return BatchExecutionEnvironment.video(
            ffmpegContext: ffmpegContext,
            preparedVideoSources: preparedVideoSources
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
            preparedContext = await Self.prepareVideoSourceContext(
                for: preparedSource.sourceURL,
                outputFileType: nil
            )
        }

        return BatchExecutionEnvironment.video(
            ffmpegContext: VideoConversionEngine.makeFFmpegExecutionContext(
                using: services.ffmpegRuntimeProvider
            ),
            preparedVideoSources: [preparedSource.sourceID: preparedContext]
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

        return BatchExecutionEnvironment.audio(
            ffmpegContext: ffmpegContext,
            preparedAudioCapabilities: preparedAudioCapabilities
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

        return BatchExecutionEnvironment.image(
            ffmpegContext: ffmpegContext,
            preparedImageCapabilities: preparedImageCapabilities
        )
    }
}
