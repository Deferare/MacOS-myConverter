import Foundation

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

    private struct Metadata {
        let errorDescription: String
        let debugInfo: String
    }

    private enum Kind: Hashable {
        case unsupportedSource
        case unreadableAsset
        case noTracksFound
        case noVideoTrackFound
        case invalidCustomVideoBitRate
        case noCompatiblePreset
        case cannotCreateExportSession
        case unsupportedOutputType
        case exportCancelled
        case exportFailed
        case ffmpegUnavailable
        case ffmpegFailed
        case outputSaveFailed
    }

    private static let metadataByKind: [Kind: Metadata] = [
        .unsupportedSource: Metadata(
            errorDescription: "Failed to read input files.",
            debugInfo: "Unsupported codec/container for this source."
        ),
        .unreadableAsset: Metadata(
            errorDescription: "Could not parse input video file.",
            debugInfo: "Input file parser failed (codec/container might be unsupported)."
        ),
        .noTracksFound: Metadata(
            errorDescription: "No video/audio tracks found.",
            debugInfo: "Video/Audio track not detected."
        ),
        .noVideoTrackFound: Metadata(
            errorDescription: "No video track found.",
            debugInfo: "Video track not detected."
        ),
        .exportCancelled: Metadata(
            errorDescription: "Conversion cancelled.",
            debugInfo: "Status: cancelled"
        ),
        .ffmpegUnavailable: Metadata(
            errorDescription: "AVFoundation cannot open this source and ffmpeg was not found.",
            debugInfo: "brew install ffmpeg or include ffmpeg in app bundle."
        )
    ]

    private var kind: Kind {
        switch self {
        case .unsupportedSource:
            .unsupportedSource
        case .unreadableAsset:
            .unreadableAsset
        case .noTracksFound:
            .noTracksFound
        case .noVideoTrackFound:
            .noVideoTrackFound
        case .invalidCustomVideoBitRate:
            .invalidCustomVideoBitRate
        case .noCompatiblePreset:
            .noCompatiblePreset
        case .cannotCreateExportSession:
            .cannotCreateExportSession
        case .unsupportedOutputType:
            .unsupportedOutputType
        case .exportCancelled:
            .exportCancelled
        case .exportFailed:
            .exportFailed
        case .ffmpegUnavailable:
            .ffmpegUnavailable
        case .ffmpegFailed:
            .ffmpegFailed
        case .outputSaveFailed:
            .outputSaveFailed
        }
    }

    private var metadata: Metadata {
        switch self {
        case .invalidCustomVideoBitRate(let value):
            return Metadata(
                errorDescription: "Custom Video Bit Rate must be an integer greater than 1 (Kbps).",
                debugInfo: "Input value: \(value)"
            )
        case .noCompatiblePreset(let presets):
            return Metadata(
                errorDescription: "No compatible export preset found in AVFoundation.",
                debugInfo: "Supported presets: \(presets.joined(separator: ", "))"
            )
        case .cannotCreateExportSession(let preset):
            return Metadata(
                errorDescription: "Could not create conversion session.",
                debugInfo: "Failed to create session with preset: \(preset)"
            )
        case .unsupportedOutputType(let format):
            return Metadata(
                errorDescription: "\(format.displayName) output is not supported on this device.",
                debugInfo: "Does not allow .\(format.fileExtension) as outputFileType."
            )
        case .exportFailed(let underlying, let preset):
            if let underlying {
                return Metadata(
                    errorDescription: "AVAssetExportSession conversion failed.",
                    debugInfo: "Preset: \(preset), Detail: \(underlying.localizedDescription)"
                )
            }
            return Metadata(
                errorDescription: "AVAssetExportSession conversion failed.",
                debugInfo: "Preset: \(preset)"
            )
        case .ffmpegFailed(let code, let output):
            let errorDescription: String
            if output.localizedCaseInsensitiveContains("operation not permitted") ||
                output.localizedCaseInsensitiveContains("permission denied") {
                errorDescription = "Conversion failed due to file permission issues. Please check input file permissions."
            } else if output.localizedCaseInsensitiveContains("unknown encoder") ||
                output.localizedCaseInsensitiveContains("encoder not found") {
                errorDescription = "Selected output format is not supported by the bundled ffmpeg encoders."
            } else {
                errorDescription = "FFmpeg conversion failed."
            }

            return Metadata(
                errorDescription: errorDescription,
                debugInfo: "FFmpeg exit code: \(code). Detail: \(output)"
            )
        case .outputSaveFailed(let path, let reason):
            return Metadata(
                errorDescription: "Failed to save output file. Please check app storage permissions.",
                debugInfo: "Save path: \(path), Detail: \(reason)"
            )
        default:
            return Self.metadataByKind[kind] ?? Metadata(
                errorDescription: "Conversion failed.",
                debugInfo: "No additional debug information."
            )
        }
    }

    var errorDescription: String? { metadata.errorDescription }

    var debugInfo: String { metadata.debugInfo }
}
