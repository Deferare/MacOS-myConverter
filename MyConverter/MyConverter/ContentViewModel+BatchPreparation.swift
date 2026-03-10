import AVFoundation
import Foundation

extension ContentViewModel {
    struct BatchExecutionEnvironment: Sendable {
        let kind: MediaKind
        let outputDirectoryURL: URL
        let videoFFmpegContext: VideoConversionEngine.FFmpegExecutionContext?
        let imageFFmpegContext: ImageConversionEngine.FFmpegExecutionContext?
        let preparedVideoSources: [String: VideoConversionEngine.PreparedSourceContext]
        let preparedAudioCapabilities: [String: AudioSourceCapabilities]
        let preparedImageCapabilities: [String: ImageSourceCapabilities]
    }

    func emptyBatchExecutionEnvironment(
        for kind: MediaKind,
        outputDirectoryURL: URL
    ) -> BatchExecutionEnvironment {
        BatchExecutionEnvironment(
            kind: kind,
            outputDirectoryURL: outputDirectoryURL,
            videoFFmpegContext: nil,
            imageFFmpegContext: nil,
            preparedVideoSources: [:],
            preparedAudioCapabilities: [:],
            preparedImageCapabilities: [:]
        )
    }

    func makeVideoFFmpegExecutionContext() -> VideoConversionEngine.FFmpegExecutionContext? {
        guard let ffmpegPath = FFmpegBinaryLocator.findPath(),
              let introspection = try? VideoConversionEngine.inspectFFmpeg(at: ffmpegPath) else {
            return nil
        }

        return VideoConversionEngine.FFmpegExecutionContext(
            ffmpegPath: ffmpegPath,
            introspection: introspection
        )
    }

    func makeImageFFmpegExecutionContext() -> ImageConversionEngine.FFmpegExecutionContext? {
        guard let ffmpegPath = FFmpegBinaryLocator.findPath(),
              let introspection = try? ImageConversionEngine.inspectFFmpeg(at: ffmpegPath) else {
            return nil
        }

        return ImageConversionEngine.FFmpegExecutionContext(
            ffmpegPath: ffmpegPath,
            introspection: introspection
        )
    }

    func prepareVideoBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        outputSettings: VideoOutputSettings,
        outputDirectoryURL: URL
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = makeVideoFFmpegExecutionContext()
        let outputFileType = outputSettings.containerFormat.avFileType
        let preparedVideoSources = await withTaskGroup(
            of: (String, VideoConversionEngine.PreparedSourceContext)?.self,
            returning: [String: VideoConversionEngine.PreparedSourceContext].self
        ) { group in
            for preparedSource in preparedSources {
                group.addTask {
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

                    let context = VideoConversionEngine.PreparedSourceContext(
                        sourceCapabilities: sourceCapabilities,
                        assetTrackProbe: assetTrackProbe,
                        candidatePresets: candidatePresets
                    )
                    return (preparedSource.sourceID, context)
                }
            }

            var prepared: [String: VideoConversionEngine.PreparedSourceContext] = [:]
            for await result in group {
                guard let (sourceID, context) = result else { continue }
                prepared[sourceID] = context
            }
            return prepared
        }

        return BatchExecutionEnvironment(
            kind: .video,
            outputDirectoryURL: outputDirectoryURL,
            videoFFmpegContext: ffmpegContext,
            imageFFmpegContext: nil,
            preparedVideoSources: preparedVideoSources,
            preparedAudioCapabilities: [:],
            preparedImageCapabilities: [:]
        )
    }

    func prepareAudioBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        outputDirectoryURL: URL
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = makeVideoFFmpegExecutionContext()
        let preparedAudioCapabilities = await withTaskGroup(
            of: (String, AudioSourceCapabilities)?.self,
            returning: [String: AudioSourceCapabilities].self
        ) { group in
            for preparedSource in preparedSources {
                group.addTask {
                    let capabilities = await VideoConversionEngine.sourceCapabilitiesForAudio(
                        for: preparedSource.sourceURL
                    )
                    return (preparedSource.sourceID, capabilities)
                }
            }

            var prepared: [String: AudioSourceCapabilities] = [:]
            for await result in group {
                guard let (sourceID, capabilities) = result else { continue }
                prepared[sourceID] = capabilities
            }
            return prepared
        }

        return BatchExecutionEnvironment(
            kind: .audio,
            outputDirectoryURL: outputDirectoryURL,
            videoFFmpegContext: ffmpegContext,
            imageFFmpegContext: nil,
            preparedVideoSources: [:],
            preparedAudioCapabilities: preparedAudioCapabilities,
            preparedImageCapabilities: [:]
        )
    }

    func prepareImageBatchExecutionEnvironment(
        preparedSources: [PreparedSourceConversion],
        outputDirectoryURL: URL
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = makeImageFFmpegExecutionContext()
        let preparedImageCapabilities = await withTaskGroup(
            of: (String, ImageSourceCapabilities)?.self,
            returning: [String: ImageSourceCapabilities].self
        ) { group in
            for preparedSource in preparedSources {
                group.addTask {
                    let capabilities = await ImageConversionEngine.sourceCapabilities(
                        for: preparedSource.sourceURL
                    )
                    return (preparedSource.sourceID, capabilities)
                }
            }

            var prepared: [String: ImageSourceCapabilities] = [:]
            for await result in group {
                guard let (sourceID, capabilities) = result else { continue }
                prepared[sourceID] = capabilities
            }
            return prepared
        }

        return BatchExecutionEnvironment(
            kind: .image,
            outputDirectoryURL: outputDirectoryURL,
            videoFFmpegContext: nil,
            imageFFmpegContext: ffmpegContext,
            preparedVideoSources: [:],
            preparedAudioCapabilities: [:],
            preparedImageCapabilities: preparedImageCapabilities
        )
    }
}
