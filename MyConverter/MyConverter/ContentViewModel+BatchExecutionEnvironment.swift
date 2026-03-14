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

    nonisolated static func makeBatchExecutionEnvironment(
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
}
