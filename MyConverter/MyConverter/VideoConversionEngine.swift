import AVFoundation
import Foundation

enum VideoConversionEngine {
    typealias ProgressHandler = @Sendable (Double) async -> Void

    nonisolated static let ffmpegIntrospectionCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.introspection.cache")
    nonisolated(unsafe) static var ffmpegIntrospectionCache: [String: FFmpegIntrospection] = [:]
    nonisolated(unsafe) static var ffmpegIntrospectionInFlight: [String: InFlightFFmpegIntrospection] = [:]
    nonisolated static let capabilityCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.capability.cache")
    nonisolated(unsafe) static var defaultVideoFormatsCache: [String: [VideoFormatOption]] = [:]
    nonisolated(unsafe) static var defaultAudioFormatsCache: [String: [AudioFormatOption]] = [:]
    nonisolated(unsafe) static var videoEncoderOptionsCache: [String: [VideoEncoderOption]] = [:]
    nonisolated(unsafe) static var videoFormatAudioEncoderOptionsCache: [String: [AudioEncoderOption]] = [:]
    nonisolated(unsafe) static var audioFormatEncoderOptionsCache: [String: [AudioEncoderOption]] = [:]
    nonisolated static let sourceCapabilityCacheQueue = DispatchQueue(label: "myconverter.video.source.capability.cache")
    nonisolated(unsafe) static var videoSourceCapabilitiesCache: [String: VideoSourceCapabilities] = [:]
    nonisolated(unsafe) static var audioSourceCapabilitiesCache: [String: AudioSourceCapabilities] = [:]
    nonisolated static let preferredExportPresets = [
        AVAssetExportPresetPassthrough,
        AVAssetExportPresetHighestQuality,
        AVAssetExportPresetMediumQuality,
        AVAssetExportPresetLowQuality
    ]

    struct FFmpegIntrospection {
        let videoEncoders: Set<String>
        let audioEncoders: Set<String>
        let muxers: Set<String>
        let muxerExtensions: [String: [String]]
    }

    final class InFlightFFmpegIntrospection: @unchecked Sendable {
        nonisolated let group: DispatchGroup
        nonisolated(unsafe) var result: Result<FFmpegIntrospection, Error>?

        nonisolated init() {
            group = DispatchGroup()
            group.enter()
        }
    }

    struct FFmpegMuxerDescriptor {
        let name: String
        let description: String
    }
}
