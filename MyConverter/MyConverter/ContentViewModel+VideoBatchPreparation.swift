import AVFoundation
import Foundation

extension ContentViewModel {
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
            makeFFmpegContext: { provider in
                VideoConversionEngine.makeFFmpegExecutionContext(using: provider)
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
}
