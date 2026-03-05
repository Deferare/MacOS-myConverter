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

    var avFileType: AVFileType? {
        guard let avFileTypeIdentifier else { return nil }
        return AVFileType(rawValue: avFileTypeIdentifier)
    }

    var normalizedID: String {
        id.lowercased()
    }

    static func == (lhs: VideoFormatOption, rhs: VideoFormatOption) -> Bool {
        lhs.normalizedID == rhs.normalizedID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(normalizedID)
    }

    static var avFoundationDefaultFormats: [VideoFormatOption] {
        VideoFormatProfile.avFoundationProfiles.map { $0.asOption }
    }

    static var ffmpegKnownFormats: [VideoFormatOption] {
        VideoFormatProfile.ffmpegOnlyProfiles.map { $0.asOption }
    }

    static func fromFFmpegExtension(_ fileExtension: String, muxer: String) -> VideoFormatOption {
        let normalizedExtension = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()
        let profile = VideoFormatProfile.byFileExtension[normalizedExtension]
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

    static func deduplicatedAndSorted(_ formats: [VideoFormatOption]) -> [VideoFormatOption] {
        FormatOptionUtilities.deduplicatedAndSorted(
            formats,
            normalizedID: { $0.normalizedID },
            merge: { $0.merged(with: $1) },
            displayName: { $0.displayName }
        )
    }

    static func defaultSelection(from formats: [VideoFormatOption]) -> VideoFormatOption? {
        let normalized = deduplicatedAndSorted(formats)
        guard !normalized.isEmpty else { return nil }

        return FormatOptionUtilities.firstPreferredOption(
            in: normalized,
            preferredExtensions: ["mp4", "mov"],
            fileExtension: { $0.fileExtension }
        )
    }

    static func isLikelyVideoFileExtension(_ fileExtension: String) -> Bool {
        let normalized = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        guard !normalized.isEmpty else { return false }

        if let utType = UTType(filenameExtension: normalized),
           utType.conforms(to: .movie) || utType.conforms(to: .video) {
            return true
        }

        return knownVideoExtensions.contains(normalized)
    }

    static func legacyNormalizedID(from storedValue: String) -> String? {
        let normalized = storedValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }

        if normalized.contains("mp4"), let mp4 = VideoFormatProfile.byFileExtension["mp4"] {
            return mp4.id
        }
        if normalized.contains("mov"), let mov = VideoFormatProfile.byFileExtension["mov"] {
            return mov.id
        }
        if normalized.contains("m4v"), let m4v = VideoFormatProfile.byFileExtension["m4v"] {
            return m4v.id
        }

        return normalized
    }

    private func merged(with other: VideoFormatOption) -> VideoFormatOption {
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

    private static let knownVideoExtensions: Set<String> = [
        "3g2", "3gp", "asf", "avi", "dv", "f4v", "flv", "m2t", "m2ts", "m2v", "m4v",
        "gif", "mkv", "mov", "mp4", "mpeg", "mpg", "mts", "mxf", "ogv", "rm", "rmvb", "ts",
        "vob", "webm", "wmv"
    ]
}

private struct VideoFormatProfile {
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

    var asOption: VideoFormatOption {
        VideoFormatOption(
            id: id,
            displayName: displayName,
            fileExtension: fileExtension,
            avFileTypeIdentifier: avFileTypeIdentifier,
            supportsFastStart: supportsFastStart,
            supportsHEVCTag: supportsHEVCTag,
            supportsAudioTrack: supportsAudioTrack,
            supportsVideoEncoderSelection: supportsVideoEncoderSelection,
            usesGIFPalettePipeline: usesGIFPalettePipeline,
            ffmpegRequiredMuxers: ffmpegRequiredMuxers,
            preferredFFmpegMuxer: preferredFFmpegMuxer,
            allowsFFmpegAutomaticVideoCodec: allowsFFmpegAutomaticVideoCodec,
            allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec
        )
    }

    static let byIdentifier: [String: VideoFormatProfile] = {
        var map: [String: VideoFormatProfile] = [:]

        func add(
            id: String,
            displayName: String,
            fileExtension: String,
            avFileTypeIdentifier: String?,
            supportsFastStart: Bool,
            supportsHEVCTag: Bool,
            supportsAudioTrack: Bool = true,
            supportsVideoEncoderSelection: Bool = true,
            usesGIFPalettePipeline: Bool = false,
            ffmpegRequiredMuxers: [String],
            preferredFFmpegMuxer: String? = nil,
            allowsFFmpegAutomaticVideoCodec: Bool = true,
            allowsFFmpegAutomaticAudioCodec: Bool = true
        ) {
            map[id.lowercased()] = VideoFormatProfile(
                id: id.lowercased(),
                displayName: displayName,
                fileExtension: fileExtension.lowercased(),
                avFileTypeIdentifier: avFileTypeIdentifier,
                supportsFastStart: supportsFastStart,
                supportsHEVCTag: supportsHEVCTag,
                supportsAudioTrack: supportsAudioTrack,
                supportsVideoEncoderSelection: supportsVideoEncoderSelection,
                usesGIFPalettePipeline: usesGIFPalettePipeline,
                ffmpegRequiredMuxers: ffmpegRequiredMuxers.map { $0.lowercased() },
                preferredFFmpegMuxer: preferredFFmpegMuxer?.lowercased(),
                allowsFFmpegAutomaticVideoCodec: allowsFFmpegAutomaticVideoCodec,
                allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec
            )
        }

        add(
            id: AVFileType.mp4.rawValue,
            displayName: "MP4",
            fileExtension: "mp4",
            avFileTypeIdentifier: AVFileType.mp4.rawValue,
            supportsFastStart: true,
            supportsHEVCTag: true,
            ffmpegRequiredMuxers: ["mp4"],
            preferredFFmpegMuxer: "mp4"
        )
        add(
            id: AVFileType.mov.rawValue,
            displayName: "MOV",
            fileExtension: "mov",
            avFileTypeIdentifier: AVFileType.mov.rawValue,
            supportsFastStart: false,
            supportsHEVCTag: true,
            ffmpegRequiredMuxers: ["mov"],
            preferredFFmpegMuxer: "mov"
        )
        add(
            id: AVFileType.m4v.rawValue,
            displayName: "M4V",
            fileExtension: "m4v",
            avFileTypeIdentifier: AVFileType.m4v.rawValue,
            supportsFastStart: true,
            supportsHEVCTag: false,
            ffmpegRequiredMuxers: ["ipod", "mp4"],
            preferredFFmpegMuxer: "ipod"
        )

        add(
            id: "ffmpeg.mkv",
            displayName: "Matroska",
            fileExtension: "mkv",
            avFileTypeIdentifier: nil,
            supportsFastStart: false,
            supportsHEVCTag: false,
            ffmpegRequiredMuxers: ["matroska"],
            preferredFFmpegMuxer: "matroska"
        )
        add(
            id: "ffmpeg.webm",
            displayName: "WebM",
            fileExtension: "webm",
            avFileTypeIdentifier: nil,
            supportsFastStart: false,
            supportsHEVCTag: false,
            ffmpegRequiredMuxers: ["webm"],
            preferredFFmpegMuxer: "webm"
        )
        add(
            id: "ffmpeg.avi",
            displayName: "AVI",
            fileExtension: "avi",
            avFileTypeIdentifier: nil,
            supportsFastStart: false,
            supportsHEVCTag: false,
            ffmpegRequiredMuxers: ["avi"],
            preferredFFmpegMuxer: "avi"
        )
        add(
            id: "ffmpeg.flv",
            displayName: "FLV",
            fileExtension: "flv",
            avFileTypeIdentifier: nil,
            supportsFastStart: false,
            supportsHEVCTag: false,
            ffmpegRequiredMuxers: ["flv"],
            preferredFFmpegMuxer: "flv"
        )
        add(
            id: "ffmpeg.3gp",
            displayName: "3GP",
            fileExtension: "3gp",
            avFileTypeIdentifier: nil,
            supportsFastStart: false,
            supportsHEVCTag: false,
            ffmpegRequiredMuxers: ["3gp"],
            preferredFFmpegMuxer: "3gp"
        )
        add(
            id: "ffmpeg.ts",
            displayName: "MPEG-TS",
            fileExtension: "ts",
            avFileTypeIdentifier: nil,
            supportsFastStart: false,
            supportsHEVCTag: false,
            ffmpegRequiredMuxers: ["mpegts"],
            preferredFFmpegMuxer: "mpegts"
        )
        add(
            id: "ffmpeg.ogv",
            displayName: "Ogg Video",
            fileExtension: "ogv",
            avFileTypeIdentifier: nil,
            supportsFastStart: false,
            supportsHEVCTag: false,
            ffmpegRequiredMuxers: ["ogg"],
            preferredFFmpegMuxer: "ogg"
        )
        add(
            id: "ffmpeg.gif",
            displayName: "GIF",
            fileExtension: "gif",
            avFileTypeIdentifier: nil,
            supportsFastStart: false,
            supportsHEVCTag: false,
            supportsAudioTrack: false,
            supportsVideoEncoderSelection: false,
            usesGIFPalettePipeline: true,
            ffmpegRequiredMuxers: ["gif"],
            preferredFFmpegMuxer: "gif",
            allowsFFmpegAutomaticVideoCodec: true,
            allowsFFmpegAutomaticAudioCodec: false
        )

        return map
    }()

    static let byFileExtension: [String: VideoFormatProfile] = {
        var map: [String: VideoFormatProfile] = [:]
        for profile in byIdentifier.values {
            map[profile.fileExtension] = profile
        }

        if let mpegTs = map["ts"] {
            map["m2ts"] = map["m2ts"] ?? mpegTs
            map["mts"] = map["mts"] ?? mpegTs
        }
        if let mkv = map["mkv"] {
            map["mk3d"] = map["mk3d"] ?? mkv
        }
        if let mp4 = map["mp4"] {
            map["m4p"] = map["m4p"] ?? mp4
        }

        return map
    }()

    static let avFoundationProfiles: [VideoFormatProfile] = {
        [
            byIdentifier[AVFileType.mp4.rawValue.lowercased()],
            byIdentifier[AVFileType.mov.rawValue.lowercased()],
            byIdentifier[AVFileType.m4v.rawValue.lowercased()]
        ].compactMap { $0 }
    }()

    static let ffmpegOnlyProfiles: [VideoFormatProfile] = {
        [
            byIdentifier["ffmpeg.mkv"],
            byIdentifier["ffmpeg.webm"],
            byIdentifier["ffmpeg.avi"],
            byIdentifier["ffmpeg.flv"],
            byIdentifier["ffmpeg.3gp"],
            byIdentifier["ffmpeg.ts"],
            byIdentifier["ffmpeg.ogv"],
            byIdentifier["ffmpeg.gif"]
        ].compactMap { $0 }
    }()
}
