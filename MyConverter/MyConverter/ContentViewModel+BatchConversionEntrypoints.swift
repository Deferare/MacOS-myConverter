import Foundation

extension ContentViewModel {
    func performVideoConversion() async {
        await MediaKind.video.performConversion(
            in: self,
            fileExtension: selectedOutputFormatFileExtension(
                using: Self.videoOutputFormatDescriptor
            ),
            buildOutputSettings: { try self.buildVideoOutputSettings() },
            prepareBatchEnvironment: { preparedSources, outputSettings in
                await ContentViewModel.prepareVideoBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    outputSettings: outputSettings,
                    runtimeProvider: self.services.ffmpegRuntimeProvider
                )
            },
            prepareSingleSourceEnvironment: { preparedSource, outputSettings in
                await self.prepareSingleVideoBatchExecutionEnvironment(
                    preparedSource: preparedSource,
                    outputSettings: outputSettings
                )
            },
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await VideoConversionEngine.convert(
                    inputURL: preparedSource.sourceURL,
                    outputURL: preparedSource.workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil,
                    ffmpegContext: environment.videoFFmpegContext,
                    preparedSourceContext: environment.preparedVideoSources[preparedSource.sourceID],
                    onProgress: MediaKind.video.batchProgressHandler(
                        in: self,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func performImageConversion() async {
        await MediaKind.image.performConversion(
            in: self,
            fileExtension: selectedOutputFormatFileExtension(
                using: Self.imageOutputFormatDescriptor
            ),
            buildOutputSettings: { self.buildImageOutputSettings() },
            prepareBatchEnvironment: { preparedSources, _ in
                await ContentViewModel.prepareImageBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    runtimeProvider: self.services.ffmpegRuntimeProvider
                )
            },
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await ImageConversionEngine.convert(
                    inputURL: preparedSource.sourceURL,
                    outputURL: preparedSource.workingOutputURL,
                    outputSettings: outputSettings,
                    ffmpegContext: environment.imageFFmpegContext,
                    onProgress: MediaKind.image.batchProgressHandler(
                        in: self,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }

    func performAudioConversion() async {
        await MediaKind.audio.performConversion(
            in: self,
            fileExtension: selectedOutputFormatFileExtension(
                using: Self.audioOutputFormatDescriptor
            ),
            buildOutputSettings: { self.buildAudioOutputSettings() },
            prepareBatchEnvironment: { preparedSources, _ in
                await ContentViewModel.prepareAudioBatchExecutionEnvironment(
                    preparedSources: preparedSources,
                    runtimeProvider: self.services.ffmpegRuntimeProvider
                )
            },
            runConversion: { preparedSource, environment, outputSettings, index, totalCount in
                try await VideoConversionEngine.convertAudio(
                    inputURL: preparedSource.sourceURL,
                    outputURL: preparedSource.workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil,
                    ffmpegContext: environment.videoFFmpegContext,
                    runtimeProvider: self.services.ffmpegRuntimeProvider,
                    onProgress: MediaKind.audio.batchProgressHandler(
                        in: self,
                        index: index,
                        totalCount: totalCount
                    )
                )
            }
        )
    }
}
