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

    struct BatchPreparationDescriptor<Value: Sendable> {
        let makeFFmpegContext: @Sendable (any FFmpegRuntimeProviding) -> FFmpegExecutionContext?
        let buildValue: @Sendable (PreparedSourceConversion) async -> Value
        let makeEnvironment: @Sendable (FFmpegExecutionContext?, [String: Value]) -> BatchExecutionEnvironment
    }

    nonisolated private static func makeBatchExecutionEnvironment(
        videoFFmpegContext: FFmpegExecutionContext? = nil,
        imageFFmpegContext: FFmpegExecutionContext? = nil,
        preparedVideoSources: [String: VideoConversionEngine.PreparedSourceContext] = [:],
        preparedAudioCapabilities: [String: AudioSourceCapabilities] = [:],
        preparedImageCapabilities: [String: ImageSourceCapabilities] = [:]
    ) -> BatchExecutionEnvironment {
        BatchExecutionEnvironment(
            videoFFmpegContext: videoFFmpegContext,
            imageFFmpegContext: imageFFmpegContext,
            preparedVideoSources: preparedVideoSources,
            preparedAudioCapabilities: preparedAudioCapabilities,
            preparedImageCapabilities: preparedImageCapabilities
        )
    }

    nonisolated private static func makeVideoBatchPreparationDescriptor(
        outputFileType: AVFileType?
    ) -> BatchPreparationDescriptor<VideoConversionEngine.PreparedSourceContext> {
        BatchPreparationDescriptor(
            makeFFmpegContext: { runtimeProvider in
                VideoConversionEngine.makeFFmpegExecutionContext(using: runtimeProvider)
            },
            buildValue: { preparedSource in
                await prepareVideoSourceContext(
                    for: preparedSource.sourceURL,
                    outputFileType: outputFileType
                )
            },
            makeEnvironment: { ffmpegContext, preparedVideoSources in
                makeBatchExecutionEnvironment(
                    videoFFmpegContext: ffmpegContext,
                    preparedVideoSources: preparedVideoSources
                )
            }
        )
    }

    private static let audioBatchPreparationDescriptor = BatchPreparationDescriptor<AudioSourceCapabilities>(
        makeFFmpegContext: { runtimeProvider in
            VideoConversionEngine.makeFFmpegExecutionContext(using: runtimeProvider)
        },
        buildValue: { preparedSource in
            await VideoConversionEngine.sourceCapabilitiesForAudio(for: preparedSource.sourceURL)
        },
        makeEnvironment: { ffmpegContext, preparedAudioCapabilities in
            makeBatchExecutionEnvironment(
                videoFFmpegContext: ffmpegContext,
                preparedAudioCapabilities: preparedAudioCapabilities
            )
        }
    )

    private static let imageBatchPreparationDescriptor = BatchPreparationDescriptor<ImageSourceCapabilities>(
        makeFFmpegContext: { runtimeProvider in
            ImageConversionEngine.makeFFmpegExecutionContext(using: runtimeProvider)
        },
        buildValue: { preparedSource in
            await ImageConversionEngine.sourceCapabilities(for: preparedSource.sourceURL)
        },
        makeEnvironment: { ffmpegContext, preparedImageCapabilities in
            makeBatchExecutionEnvironment(
                imageFFmpegContext: ffmpegContext,
                preparedImageCapabilities: preparedImageCapabilities
            )
        }
    )

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

    nonisolated static func prepareBatchExecutionEnvironment<Value: Sendable>(
        preparedSources: [PreparedSourceConversion],
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider(),
        using descriptor: BatchPreparationDescriptor<Value>
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = descriptor.makeFFmpegContext(runtimeProvider)
        let preparedValues = await collectPreparedSourceValues(
            from: preparedSources,
            buildValue: descriptor.buildValue
        )
        return descriptor.makeEnvironment(ffmpegContext, preparedValues)
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
        let outputFileType = outputSettings.containerFormat.avFileType
        return await prepareBatchExecutionEnvironment(
            preparedSources: preparedSources,
            runtimeProvider: runtimeProvider,
            using: makeVideoBatchPreparationDescriptor(outputFileType: outputFileType)
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

        return Self.makeBatchExecutionEnvironment(
            videoFFmpegContext: VideoConversionEngine.makeFFmpegExecutionContext(
                using: services.ffmpegRuntimeProvider
            ),
            preparedVideoSources: [preparedSource.sourceID: preparedContext]
        )
    }

    nonisolated static func prepareAudioBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) async -> BatchExecutionEnvironment {
        return await prepareBatchExecutionEnvironment(
            preparedSources: preparedSources,
            runtimeProvider: runtimeProvider,
            using: audioBatchPreparationDescriptor
        )
    }

    nonisolated static func prepareImageBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) async -> BatchExecutionEnvironment {
        return await prepareBatchExecutionEnvironment(
            preparedSources: preparedSources,
            runtimeProvider: runtimeProvider,
            using: imageBatchPreparationDescriptor
        )
    }
}
