import Foundation

struct ConversionErrorMetadata {
    let errorDescription: String
    let debugInfo: String
}

enum ConversionErrorKind: Hashable {
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

extension ConversionError {
    var kind: ConversionErrorKind {
        ConversionErrorKind.resolve(from: self)
    }
}
