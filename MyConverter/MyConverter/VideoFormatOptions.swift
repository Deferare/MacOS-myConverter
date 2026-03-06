import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct VideoFormatOption: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let fileExtension: String
    let avFileTypeIdentifier: String?
    let supportsFastStart: Bool
    let supportsHEVCTag: Bool
    let supportsAudioTrack: Bool
    let supportsVideoEncoderSelection: Bool
    let usesGIFPalettePipeline: Bool
    let ffmpegRequiredMuxers: [String]
    let preferredFFmpegMuxer: String?
    let allowsFFmpegAutomaticVideoCodec: Bool
    let allowsFFmpegAutomaticAudioCodec: Bool

    nonisolated var avFileType: AVFileType? {
        guard let avFileTypeIdentifier else { return nil }
        return AVFileType(rawValue: avFileTypeIdentifier)
    }

    nonisolated var normalizedID: String {
        id.lowercased()
    }

    static func == (lhs: VideoFormatOption, rhs: VideoFormatOption) -> Bool {
        lhs.normalizedID == rhs.normalizedID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(normalizedID)
    }

    nonisolated static let avFoundationDefaultFormats: [VideoFormatOption] = {
        VideoFormatCatalog.avFoundationProfiles.map { $0.asOption }
    }()

    nonisolated static let ffmpegKnownFormats: [VideoFormatOption] = {
        VideoFormatCatalog.ffmpegOnlyProfiles.map { $0.asOption }
    }()

    nonisolated static func fromFFmpegExtension(_ fileExtension: String, muxer: String) -> VideoFormatOption {
        let normalizedExtension = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()
        let profile = VideoFormatCatalog.byFileExtension[normalizedExtension]
        let resolved = FormatOptionUtilities.resolveFFmpegFormatMetadata(
            fileExtension: fileExtension,
            muxer: normalizedMuxer,
            profile: profile,
            profileID: { $0.id },
            profileDisplayName: { $0.displayName },
            profileFileExtension: { $0.fileExtension },
            profileRequiredMuxers: { $0.ffmpegRequiredMuxers },
            profilePreferredMuxer: { $0.preferredFFmpegMuxer }
        )

        return VideoFormatOption(
            id: resolved.id,
            displayName: resolved.displayName,
            fileExtension: resolved.fileExtension,
            avFileTypeIdentifier: profile?.avFileTypeIdentifier,
            supportsFastStart: profile?.supportsFastStart ?? false,
            supportsHEVCTag: profile?.supportsHEVCTag ?? false,
            supportsAudioTrack: profile?.supportsAudioTrack ?? true,
            supportsVideoEncoderSelection: profile?.supportsVideoEncoderSelection ?? true,
            usesGIFPalettePipeline: profile?.usesGIFPalettePipeline ?? false,
            ffmpegRequiredMuxers: resolved.requiredMuxers,
            preferredFFmpegMuxer: resolved.preferredMuxer,
            allowsFFmpegAutomaticVideoCodec: profile?.allowsFFmpegAutomaticVideoCodec ?? true,
            allowsFFmpegAutomaticAudioCodec: profile?.allowsFFmpegAutomaticAudioCodec ?? true
        )
    }

    nonisolated static func deduplicatedAndSorted(_ formats: [VideoFormatOption]) -> [VideoFormatOption] {
        FormatOptionUtilities.deduplicatedAndSorted(
            formats,
            normalizedID: { $0.normalizedID },
            merge: { $0.merged(with: $1) },
            displayName: { $0.displayName }
        )
    }

    nonisolated static func defaultSelection(from formats: [VideoFormatOption]) -> VideoFormatOption? {
        let normalized = deduplicatedAndSorted(formats)
        guard !normalized.isEmpty else { return nil }

        return FormatOptionUtilities.firstPreferredOption(
            in: normalized,
            preferredExtensions: ["mp4", "mov"],
            fileExtension: { $0.fileExtension }
        )
    }

    nonisolated static func isLikelyVideoFileExtension(_ fileExtension: String) -> Bool {
        let normalized = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        guard !normalized.isEmpty else { return false }

        if let utType = FormatOptionUtilities.cachedUTType(forFilenameExtension: normalized),
           utType.conforms(to: .movie) || utType.conforms(to: .video) {
            return true
        }

        return knownVideoExtensions.contains(normalized)
    }

    nonisolated static func legacyNormalizedID(from storedValue: String) -> String? {
        let normalized = storedValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }

        if normalized.contains("mp4"), let mp4 = VideoFormatCatalog.byFileExtension["mp4"] {
            return mp4.id
        }
        if normalized.contains("mov"), let mov = VideoFormatCatalog.byFileExtension["mov"] {
            return mov.id
        }
        if normalized.contains("m4v"), let m4v = VideoFormatCatalog.byFileExtension["m4v"] {
            return m4v.id
        }

        return normalized
    }

    nonisolated private func merged(with other: VideoFormatOption) -> VideoFormatOption {
        VideoFormatOption(
            id: id,
            displayName: FormatOptionUtilities.preferredDisplayName(displayName, other.displayName),
            fileExtension: fileExtension,
            avFileTypeIdentifier: avFileTypeIdentifier ?? other.avFileTypeIdentifier,
            supportsFastStart: supportsFastStart || other.supportsFastStart,
            supportsHEVCTag: supportsHEVCTag || other.supportsHEVCTag,
            supportsAudioTrack: supportsAudioTrack && other.supportsAudioTrack,
            supportsVideoEncoderSelection: supportsVideoEncoderSelection && other.supportsVideoEncoderSelection,
            usesGIFPalettePipeline: usesGIFPalettePipeline || other.usesGIFPalettePipeline,
            ffmpegRequiredMuxers: FormatOptionUtilities.uniqueLowercasedTrimmedStrings(
                ffmpegRequiredMuxers + other.ffmpegRequiredMuxers
            ),
            preferredFFmpegMuxer: preferredFFmpegMuxer ?? other.preferredFFmpegMuxer,
            allowsFFmpegAutomaticVideoCodec: allowsFFmpegAutomaticVideoCodec || other.allowsFFmpegAutomaticVideoCodec,
            allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec || other.allowsFFmpegAutomaticAudioCodec
        )
    }

    nonisolated private static let knownVideoExtensions: Set<String> = [
        "3g2", "3gp", "asf", "avi", "dv", "f4v", "flv", "m2t", "m2ts", "m2v", "m4v",
        "gif", "mkv", "mov", "mp4", "mpeg", "mpg", "mts", "mxf", "ogv", "rm", "rmvb", "ts",
        "vob", "webm", "wmv"
    ]
}
