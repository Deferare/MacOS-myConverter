import AVFoundation
import Foundation

enum VideoConversionEngine {
    typealias ProgressHandler = @Sendable (Double) async -> Void

    static let ffmpegIntrospectionCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.introspection.cache")
    nonisolated(unsafe) static var ffmpegIntrospectionCache: [String: FFmpegIntrospection] = [:]
    static let capabilityCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.capability.cache")
    nonisolated(unsafe) static var defaultVideoFormatsCache: [String: [VideoFormatOption]] = [:]
    nonisolated(unsafe) static var defaultAudioFormatsCache: [String: [AudioFormatOption]] = [:]
    nonisolated(unsafe) static var videoEncoderOptionsCache: [String: [VideoEncoderOption]] = [:]
    nonisolated(unsafe) static var videoFormatAudioEncoderOptionsCache: [String: [AudioEncoderOption]] = [:]
    nonisolated(unsafe) static var audioFormatEncoderOptionsCache: [String: [AudioEncoderOption]] = [:]
    static let preferredExportPresets = [
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

    struct FFmpegMuxerDescriptor {
        let name: String
        let description: String
    }
}
