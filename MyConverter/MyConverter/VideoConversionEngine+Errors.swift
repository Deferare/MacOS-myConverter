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

    private static let metadataProviderByKind: [Kind: (Self) -> Metadata] = [
        .unsupportedSource: { _ in
            Metadata(
                errorDescription: "Failed to read input files.",
                debugInfo: "Unsupported codec/container for this source."
            )
        },
        .unreadableAsset: { _ in
            Metadata(
                errorDescription: "Could not parse input video file.",
                debugInfo: "Input file parser failed (codec/container might be unsupported)."
            )
        },
        .noTracksFound: { _ in
            Metadata(
                errorDescription: "No video/audio tracks found.",
                debugInfo: "Video/Audio track not detected."
            )
        },
        .noVideoTrackFound: { _ in
            Metadata(
                errorDescription: "No video track found.",
                debugInfo: "Video track not detected."
            )
        },
        .invalidCustomVideoBitRate: { error in
            guard case let .invalidCustomVideoBitRate(value) = error else {
                return Metadata(
                    errorDescription: "Custom Video Bit Rate must be an integer greater than 1 (Kbps).",
                    debugInfo: "Input value unavailable."
                )
            }
            return Metadata(
                errorDescription: "Custom Video Bit Rate must be an integer greater than 1 (Kbps).",
                debugInfo: "Input value: \(value)"
            )
        },
        .noCompatiblePreset: { error in
            guard case let .noCompatiblePreset(presets) = error else {
                return Metadata(
                    errorDescription: "No compatible export preset found in AVFoundation.",
                    debugInfo: "Supported presets unavailable."
                )
            }
            return Metadata(
                errorDescription: "No compatible export preset found in AVFoundation.",
                debugInfo: "Supported presets: \(presets.joined(separator: ", "))"
            )
        },
        .cannotCreateExportSession: { error in
            guard case let .cannotCreateExportSession(preset) = error else {
                return Metadata(
                    errorDescription: "Could not create conversion session.",
                    debugInfo: "Preset unavailable."
                )
            }
            return Metadata(
                errorDescription: "Could not create conversion session.",
                debugInfo: "Failed to create session with preset: \(preset)"
            )
        },
        .unsupportedOutputType: { error in
            guard case let .unsupportedOutputType(format) = error else {
                return Metadata(
                    errorDescription: "Output is not supported on this device.",
                    debugInfo: "Output file type unavailable."
                )
            }
            return Metadata(
                errorDescription: "\(format.displayName) output is not supported on this device.",
                debugInfo: "Does not allow .\(format.fileExtension) as outputFileType."
            )
        },
        .exportCancelled: { _ in
            Metadata(
                errorDescription: "Conversion cancelled.",
                debugInfo: "Status: cancelled"
            )
        },
        .exportFailed: { error in
            guard case let .exportFailed(underlying, preset) = error else {
                return Metadata(
                    errorDescription: "AVAssetExportSession conversion failed.",
                    debugInfo: "Preset unavailable."
                )
            }
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
        },
        .ffmpegUnavailable: { _ in
            Metadata(
                errorDescription: "AVFoundation cannot open this source and ffmpeg was not found.",
                debugInfo: "brew install ffmpeg or include ffmpeg in app bundle."
            )
        },
        .ffmpegFailed: { error in
            guard case let .ffmpegFailed(code, output) = error else {
                return Metadata(
                    errorDescription: "FFmpeg conversion failed.",
                    debugInfo: "FFmpeg error details unavailable."
                )
            }

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
        },
        .outputSaveFailed: { error in
            guard case let .outputSaveFailed(path, reason) = error else {
                return Metadata(
                    errorDescription: "Failed to save output file. Please check app storage permissions.",
                    debugInfo: "Save path unavailable."
                )
            }
            return Metadata(
                errorDescription: "Failed to save output file. Please check app storage permissions.",
                debugInfo: "Save path: \(path), Detail: \(reason)"
            )
        }
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
        Self.metadataProviderByKind[kind]?(self) ?? Metadata(
            errorDescription: "Conversion failed.",
            debugInfo: "No additional debug information."
        )
    }

    var errorDescription: String? { metadata.errorDescription }

    var debugInfo: String { metadata.debugInfo }
}
