import Foundation

extension ContentViewModel {
    nonisolated static func prepareAudioBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) async -> BatchExecutionEnvironment {
        await prepareBatchExecutionEnvironment(
            preparedSources: preparedSources,
            runtimeProvider: runtimeProvider,
            makeFFmpegContext: { provider in
                VideoConversionEngine.makeFFmpegExecutionContext(using: provider)
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
    }

    nonisolated static func prepareImageBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) async -> BatchExecutionEnvironment {
        await prepareBatchExecutionEnvironment(
            preparedSources: preparedSources,
            runtimeProvider: runtimeProvider,
            makeFFmpegContext: { provider in
                ImageConversionEngine.makeFFmpegExecutionContext(using: provider)
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
    }
}
