import AVFoundation
import Foundation

struct VideoOutputSettings {
    let containerFormat: VideoFormatOption
    let videoCodecCandidates: [String]
    let useHEVCTag: Bool
    let resolution: (width: Int, height: Int)?
    let frameRate: Int?
    let gifPlaybackSpeed: Double?
    let videoBitRateKbps: Int?
    let audioCodecCandidates: [String]
    let audioChannels: Int?
    let sampleRate: Int?
    let audioBitRateKbps: Int?
}

struct VideoSourceCapabilities {
    let availableOutputFormats: [VideoFormatOption]
    let warningMessage: String?
    let errorMessage: String?
}

struct AudioOutputSettings {
    let containerFormat: AudioFormatOption
    let audioCodecCandidates: [String]
    let audioChannels: Int?
    let sampleRate: Int?
    let audioBitRateKbps: Int?
}

struct AudioSourceCapabilities {
    let availableOutputFormats: [AudioFormatOption]
    let warningMessage: String?
    let errorMessage: String?
}

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

    static func sandboxOutputDirectory(bundleIdentifier: String?) throws -> URL {
        let appSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let identifier = bundleIdentifier ?? "MyConverter"
        let outputDirectory = appSupportDirectory
            .appendingPathComponent(identifier, isDirectory: true)
            .appendingPathComponent("Converted", isDirectory: true)

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return outputDirectory
    }

    static func uniqueOutputURL(
        for sourceURL: URL,
        format: VideoFormatOption,
        in outputDirectory: URL
    ) -> URL {
        OutputPathUtilities.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            in: outputDirectory
        )
    }

    static func temporaryOutputURL(for sourceURL: URL, format: VideoFormatOption) -> URL {
        OutputPathUtilities.temporaryOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension
        )
    }

    static func uniqueOutputURL(
        for sourceURL: URL,
        format: AudioFormatOption,
        in outputDirectory: URL
    ) -> URL {
        OutputPathUtilities.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            in: outputDirectory
        )
    }

    static func temporaryOutputURL(for sourceURL: URL, format: AudioFormatOption) -> URL {
        OutputPathUtilities.temporaryOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension
        )
    }

    static func saveConvertedOutput(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        do {
            return try OutputPathUtilities.saveConvertedOutput(from: sourceURL, to: destinationURL)
        } catch let saveError as OutputPathUtilities.SaveOutputError {
            switch saveError {
            case let .outputSaveFailed(path, message):
                throw ConversionError.outputSaveFailed(path, message)
            }
        }
    }

    static func isFFmpegAvailable() -> Bool {
        FFmpegBinaryLocator.findPath() != nil
    }
}

enum ConversionError: LocalizedError {
    case unsupportedSource
    case unreadableAsset
    case noTracksFound
    case noVideoTrackFound
    case invalidCustomVideoBitRate(String)
    case noCompatiblePreset([String])
    case cannotCreateExportSession(String)
    case unsupportedOutputType(VideoFormatOption)
    case exportCancelled
    case exportFailed(underlying: Error?, preset: String)
    case ffmpegUnavailable
    case ffmpegFailed(Int32, String)
    case outputSaveFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "Failed to read input files."
        case .unreadableAsset:
            return "Could not parse input video file."
        case .noTracksFound:
            return "No video/audio tracks found."
        case .noVideoTrackFound:
            return "No video track found."
        case .invalidCustomVideoBitRate:
            return "Custom Video Bit Rate must be an integer greater than 1 (Kbps)."
        case .noCompatiblePreset:
            return "No compatible export preset found in AVFoundation."
        case .cannotCreateExportSession:
            return "Could not create conversion session."
        case .unsupportedOutputType(let format):
            return "\(format.displayName) output is not supported on this device."
        case .exportCancelled:
            return "Conversion cancelled."
        case .ffmpegUnavailable:
            return "AVFoundation cannot open this source and ffmpeg was not found."
        case .ffmpegFailed(_, let output):
            if output.localizedCaseInsensitiveContains("operation not permitted") ||
                output.localizedCaseInsensitiveContains("permission denied") {
                return "Conversion failed due to file permission issues. Please check input file permissions."
            }
            if output.localizedCaseInsensitiveContains("unknown encoder") ||
                output.localizedCaseInsensitiveContains("encoder not found") {
                return "Selected output format is not supported by the bundled ffmpeg encoders."
            }
            return "FFmpeg conversion failed."
        case .outputSaveFailed:
            return "Failed to save output file. Please check app storage permissions."
        case .exportFailed:
            return "AVAssetExportSession conversion failed."
        }
    }

    var debugInfo: String {
        switch self {
        case .noCompatiblePreset(let presets):
            return "Supported presets: \(presets.joined(separator: ", "))"
        case .cannotCreateExportSession(let preset):
            return "Failed to create session with preset: \(preset)"
        case .unsupportedOutputType(let format):
            return "Does not allow .\(format.fileExtension) as outputFileType."
        case .exportFailed(let underlying, let preset):
            if let underlying {
                return "Preset: \(preset), Detail: \(underlying.localizedDescription)"
            }
            return "Preset: \(preset)"
        case .exportCancelled:
            return "Status: cancelled"
        case .ffmpegUnavailable:
            return "brew install ffmpeg or include ffmpeg in app bundle."
        case .ffmpegFailed(let code, let output):
            return "FFmpeg exit code: \(code). Detail: \(output)"
        case .outputSaveFailed(let path, let reason):
            return "Save path: \(path), Detail: \(reason)"
        case .invalidCustomVideoBitRate(let value):
            return "Input value: \(value)"
        case .unreadableAsset:
            return "Input file parser failed (codec/container might be unsupported)."
        case .unsupportedSource:
            return "Unsupported codec/container for this source."
        case .noTracksFound:
            return "Video/Audio track not detected."
        case .noVideoTrackFound:
            return "Video track not detected."
        }
    }
}
