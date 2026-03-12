import AVFoundation
import Foundation

enum VideoConversionEngine {
    typealias ProgressHandler = @Sendable (Double) async -> Void

    nonisolated static let ffmpegIntrospectionCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.introspection.cache")
    nonisolated(unsafe) static var ffmpegIntrospectionCache: [String: FFmpegIntrospection] = [:]
    nonisolated(unsafe) static var ffmpegIntrospectionInFlight: [String: InFlightGroupedResult<FFmpegIntrospection>] = [:]
    nonisolated static let capabilityCacheQueue = DispatchQueue(label: "myconverter.video.ffmpeg.capability.cache")
    nonisolated(unsafe) static var defaultVideoFormatsCache: [String: [VideoFormatOption]] = [:]
    nonisolated(unsafe) static var defaultAudioFormatsCache: [String: [AudioFormatOption]] = [:]
    nonisolated(unsafe) static var videoEncoderOptionsCache: [String: [VideoEncoderOption]] = [:]
    nonisolated(unsafe) static var videoFormatAudioEncoderOptionsCache: [String: [AudioEncoderOption]] = [:]
    nonisolated(unsafe) static var audioFormatEncoderOptionsCache: [String: [AudioEncoderOption]] = [:]
    nonisolated static let exportPresetCompatibilityCacheQueue = DispatchQueue(label: "myconverter.video.exportpreset.cache")
    nonisolated(unsafe) static var exportPresetCompatibilityCache: [String: [String]] = [:]
    nonisolated(unsafe) static var exportPresetCompatibilityInFlight: [String: InFlightContinuation<[String]>] = [:]
    nonisolated(unsafe) static var exportPresetAvailabilityCache: [String: Bool] = [:]
    nonisolated(unsafe) static var exportPresetAvailabilityInFlight: [String: InFlightContinuation<Bool>] = [:]
    nonisolated static let sourceCapabilityCacheQueue = DispatchQueue(label: "myconverter.video.source.capability.cache")
    nonisolated(unsafe) static var videoSourceCapabilitiesCache: [String: VideoSourceCapabilities] = [:]
    nonisolated(unsafe) static var audioSourceCapabilitiesCache: [String: AudioSourceCapabilities] = [:]
    nonisolated(unsafe) static var assetTrackProbeCache: [String: AssetTrackProbe] = [:]
    nonisolated(unsafe) static var videoSourceCapabilitiesInFlight: [String: InFlightContinuation<VideoSourceCapabilities>] = [:]
    nonisolated(unsafe) static var audioSourceCapabilitiesInFlight: [String: InFlightContinuation<AudioSourceCapabilities>] = [:]
    nonisolated(unsafe) static var assetTrackProbeInFlight: [String: InFlightContinuation<AssetTrackProbe>] = [:]
    nonisolated static let preferredExportPresets = [
        AVAssetExportPresetPassthrough,
        AVAssetExportPresetHighestQuality,
        AVAssetExportPresetMediumQuality,
        AVAssetExportPresetLowQuality
    ]

    struct PreparedSourceContext: Sendable {
        let sourceCapabilities: VideoSourceCapabilities
        let assetTrackProbe: AssetTrackProbe
        let candidatePresets: [String]?
        let stagedInputLease: FFmpegStagingSupport.StagedInputLease?
    }

    struct FFmpegMuxerDescriptor {
        let name: String
        let description: String
    }

    struct AssetTrackProbe: Sendable {
        let isReadable: Bool
        let hasVideoTrack: Bool
        let hasAudioTrack: Bool
    }

    static func rethrowIfExportCancelled(_ error: Error) throws {
        if error is CancellationError {
            throw ConversionError.exportCancelled
        }

        if case ConversionError.exportCancelled = error {
            throw ConversionError.exportCancelled
        }
    }
}
