import Foundation

private struct ConversionErrorMetadata {
    let errorDescription: String
    let debugInfo: String
}

private enum ConversionErrorKind: Hashable {
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

    private static let kindMatchers: [(kind: Self, matches: (ConversionError) -> Bool)] = [
        (.unsupportedSource, {
            if case .unsupportedSource = $0 { return true }
            return false
        }),
        (.unreadableAsset, {
            if case .unreadableAsset = $0 { return true }
            return false
        }),
        (.noTracksFound, {
            if case .noTracksFound = $0 { return true }
            return false
        }),
        (.noVideoTrackFound, {
            if case .noVideoTrackFound = $0 { return true }
            return false
        }),
        (.invalidCustomVideoBitRate, {
            if case .invalidCustomVideoBitRate = $0 { return true }
            return false
        }),
        (.noCompatiblePreset, {
            if case .noCompatiblePreset = $0 { return true }
            return false
        }),
        (.cannotCreateExportSession, {
            if case .cannotCreateExportSession = $0 { return true }
            return false
        }),
        (.unsupportedOutputType, {
            if case .unsupportedOutputType = $0 { return true }
            return false
        }),
        (.exportCancelled, {
            if case .exportCancelled = $0 { return true }
            return false
        }),
        (.exportFailed, {
            if case .exportFailed = $0 { return true }
            return false
        }),
        (.ffmpegUnavailable, {
            if case .ffmpegUnavailable = $0 { return true }
            return false
        }),
        (.ffmpegFailed, {
            if case .ffmpegFailed = $0 { return true }
            return false
        }),
        (.outputSaveFailed, {
            if case .outputSaveFailed = $0 { return true }
            return false
        })
    ]

    static func resolve(from error: ConversionError) -> Self {
        Self.kindMatchers.first(where: { $0.matches(error) })?.kind ?? .unsupportedSource
    }
}

private enum ConversionErrorMetadataProvider {
    static func metadata(for error: ConversionError, kind: ConversionErrorKind) -> ConversionErrorMetadata {
        switch kind {
        case .unsupportedSource:
            return ConversionErrorMetadata(
                errorDescription: "Failed to read input files.",
                debugInfo: "Unsupported codec/container for this source."
            )
        case .unreadableAsset:
            return ConversionErrorMetadata(
                errorDescription: "Could not parse input video file.",
                debugInfo: "Input file parser failed (codec/container might be unsupported)."
            )
        case .noTracksFound:
            return ConversionErrorMetadata(
                errorDescription: "No video/audio tracks found.",
                debugInfo: "Video/Audio track not detected."
            )
        case .noVideoTrackFound:
            return ConversionErrorMetadata(
                errorDescription: "No video track found.",
                debugInfo: "Video track not detected."
            )
        case .invalidCustomVideoBitRate:
            guard case let .invalidCustomVideoBitRate(value) = error else {
                return ConversionErrorMetadata(
                    errorDescription: "Custom Video Bit Rate must be an integer greater than 1 (Kbps).",
                    debugInfo: "Input value unavailable."
                )
            }
            return ConversionErrorMetadata(
                errorDescription: "Custom Video Bit Rate must be an integer greater than 1 (Kbps).",
                debugInfo: "Input value: \(value)"
            )
        case .noCompatiblePreset:
            guard case let .noCompatiblePreset(presets) = error else {
                return ConversionErrorMetadata(
                    errorDescription: "No compatible export preset found in AVFoundation.",
                    debugInfo: "Supported presets unavailable."
                )
            }
            return ConversionErrorMetadata(
                errorDescription: "No compatible export preset found in AVFoundation.",
                debugInfo: "Supported presets: \(presets.joined(separator: ", "))"
            )
        case .cannotCreateExportSession:
            guard case let .cannotCreateExportSession(preset) = error else {
                return ConversionErrorMetadata(
                    errorDescription: "Could not create conversion session.",
                    debugInfo: "Preset unavailable."
                )
            }
            return ConversionErrorMetadata(
                errorDescription: "Could not create conversion session.",
                debugInfo: "Failed to create session with preset: \(preset)"
            )
        case .unsupportedOutputType:
            guard case let .unsupportedOutputType(format) = error else {
                return ConversionErrorMetadata(
                    errorDescription: "Output is not supported on this device.",
                    debugInfo: "Output file type unavailable."
                )
            }
            return ConversionErrorMetadata(
                errorDescription: "\(format.displayName) output is not supported on this device.",
                debugInfo: "Does not allow .\(format.fileExtension) as outputFileType."
            )
        case .exportCancelled:
            return ConversionErrorMetadata(
                errorDescription: "Conversion cancelled.",
                debugInfo: "Status: cancelled"
            )
        case .exportFailed:
            guard case let .exportFailed(underlying, preset) = error else {
                return ConversionErrorMetadata(
                    errorDescription: "AVAssetExportSession conversion failed.",
                    debugInfo: "Preset unavailable."
                )
            }
            if let underlying {
                return ConversionErrorMetadata(
                    errorDescription: "AVAssetExportSession conversion failed.",
                    debugInfo: "Preset: \(preset), Detail: \(underlying.localizedDescription)"
                )
            }
            return ConversionErrorMetadata(
                errorDescription: "AVAssetExportSession conversion failed.",
                debugInfo: "Preset: \(preset)"
            )
        case .ffmpegUnavailable:
            return ConversionErrorMetadata(
                errorDescription: "AVFoundation cannot open this source and ffmpeg was not found.",
                debugInfo: "brew install ffmpeg or include ffmpeg in app bundle."
            )
        case .ffmpegFailed:
            guard case let .ffmpegFailed(code, output) = error else {
                return ConversionErrorMetadata(
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

            return ConversionErrorMetadata(
                errorDescription: errorDescription,
                debugInfo: "FFmpeg exit code: \(code). Detail: \(output)"
            )
        case .outputSaveFailed:
            guard case let .outputSaveFailed(path, reason) = error else {
                return ConversionErrorMetadata(
                    errorDescription: "Failed to save output file. Please check app storage permissions.",
                    debugInfo: "Save path unavailable."
                )
            }
            return ConversionErrorMetadata(
                errorDescription: "Failed to save output file. Please check app storage permissions.",
                debugInfo: "Save path: \(path), Detail: \(reason)"
            )
        }
    }
}

extension ConversionError {
    private var kind: ConversionErrorKind {
        ConversionErrorKind.resolve(from: self)
    }

    private var metadata: ConversionErrorMetadata {
        ConversionErrorMetadataProvider.metadata(for: self, kind: kind)
    }

    var errorDescription: String? { metadata.errorDescription }

    var debugInfo: String { metadata.debugInfo }
}
