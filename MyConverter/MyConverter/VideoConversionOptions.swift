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
        let normalizedExtension = normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()
        let extensionUTType = UTType(filenameExtension: normalizedExtension)
        let profile = VideoFormatProfile.byFileExtension[normalizedExtension]

        let resolvedID =
            profile?.id ??
            extensionUTType?.identifier.lowercased() ??
            "ffmpeg.\(normalizedExtension)"

        let resolvedDisplayName =
            profile?.displayName ??
            extensionUTType?.localizedDescription ??
            normalizedExtension.uppercased()

        let resolvedExtension =
            profile?.fileExtension ??
            extensionUTType?.preferredFilenameExtension ??
            normalizedExtension

        let resolvedMuxers = uniqueStrings((profile?.ffmpegRequiredMuxers ?? []) + [normalizedMuxer])

        return VideoFormatOption(
            id: resolvedID,
            displayName: resolvedDisplayName,
            fileExtension: resolvedExtension,
            avFileTypeIdentifier: profile?.avFileTypeIdentifier,
            supportsFastStart: profile?.supportsFastStart ?? false,
            supportsHEVCTag: profile?.supportsHEVCTag ?? false,
            supportsAudioTrack: profile?.supportsAudioTrack ?? true,
            supportsVideoEncoderSelection: profile?.supportsVideoEncoderSelection ?? true,
            usesGIFPalettePipeline: profile?.usesGIFPalettePipeline ?? false,
            ffmpegRequiredMuxers: resolvedMuxers,
            preferredFFmpegMuxer: profile?.preferredFFmpegMuxer ?? normalizedMuxer,
            allowsFFmpegAutomaticVideoCodec: profile?.allowsFFmpegAutomaticVideoCodec ?? true,
            allowsFFmpegAutomaticAudioCodec: profile?.allowsFFmpegAutomaticAudioCodec ?? true
        )
    }

    static func deduplicatedAndSorted(_ formats: [VideoFormatOption]) -> [VideoFormatOption] {
        var byID: [String: VideoFormatOption] = [:]

        for format in formats {
            let key = format.normalizedID
            if let existing = byID[key] {
                byID[key] = existing.merged(with: format)
            } else {
                byID[key] = format
            }
        }

        return byID.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func defaultSelection(from formats: [VideoFormatOption]) -> VideoFormatOption? {
        let normalized = deduplicatedAndSorted(formats)
        guard !normalized.isEmpty else { return nil }

        if let preferred = normalized.first(where: { $0.fileExtension.lowercased() == "mp4" }) {
            return preferred
        }
        if let preferred = normalized.first(where: { $0.fileExtension.lowercased() == "mov" }) {
            return preferred
        }
        return normalized.first
    }

    static func isLikelyVideoFileExtension(_ fileExtension: String) -> Bool {
        let normalized = normalizedFileExtension(fileExtension)
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
            displayName: displayName.count >= other.displayName.count ? displayName : other.displayName,
            fileExtension: fileExtension,
            avFileTypeIdentifier: avFileTypeIdentifier ?? other.avFileTypeIdentifier,
            supportsFastStart: supportsFastStart || other.supportsFastStart,
            supportsHEVCTag: supportsHEVCTag || other.supportsHEVCTag,
            supportsAudioTrack: supportsAudioTrack && other.supportsAudioTrack,
            supportsVideoEncoderSelection: supportsVideoEncoderSelection && other.supportsVideoEncoderSelection,
            usesGIFPalettePipeline: usesGIFPalettePipeline || other.usesGIFPalettePipeline,
            ffmpegRequiredMuxers: Self.uniqueStrings(ffmpegRequiredMuxers + other.ffmpegRequiredMuxers),
            preferredFFmpegMuxer: preferredFFmpegMuxer ?? other.preferredFFmpegMuxer,
            allowsFFmpegAutomaticVideoCodec: allowsFFmpegAutomaticVideoCodec || other.allowsFFmpegAutomaticVideoCodec,
            allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec || other.allowsFFmpegAutomaticAudioCodec
        )
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                result.append(normalized)
            }
        }

        return result
    }

    private static func normalizedFileExtension(_ fileExtension: String) -> String {
        var normalized = fileExtension.lowercased()
        if normalized.hasPrefix(".") {
            normalized.removeFirst()
        }

        normalized = normalized
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized
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

enum VideoEncoderOption: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case h265CPU = "H.265(CPU)"
    case h265GPU = "H.265(GPU)"
    case h264CPU = "H.264(CPU)"
    case h264GPU = "H.264(GPU)"
    case av1CPU = "AV1(CPU)"
    case vp9CPU = "VP9(CPU)"
    case vp8CPU = "VP8(CPU)"
    case mpeg4CPU = "MPEG-4(CPU)"
    case mpeg2CPU = "MPEG-2(CPU)"
    case proresCPU = "ProRes(CPU)"

    var id: String { rawValue }

    var codecCandidates: [String] {
        switch self {
        case .auto:
            return []
        case .h265CPU:
            return ["libx265", "hevc", "h265"]
        case .h265GPU:
            return ["hevc_videotoolbox", "hevc", "libx265", "h265"]
        case .h264CPU:
            return ["libx264", "h264", "mpeg4"]
        case .h264GPU:
            return ["h264_videotoolbox", "h264", "libx264", "mpeg4"]
        case .av1CPU:
            return ["libsvtav1", "libaom-av1", "rav1e", "av1"]
        case .vp9CPU:
            return ["libvpx-vp9", "vp9"]
        case .vp8CPU:
            return ["libvpx", "vp8"]
        case .mpeg4CPU:
            return ["mpeg4"]
        case .mpeg2CPU:
            return ["mpeg2video"]
        case .proresCPU:
            return ["prores_ks", "prores_aw", "prores"]
        }
    }

    var usesHEVCCodec: Bool {
        switch self {
        case .h265CPU, .h265GPU:
            return true
        default:
            return false
        }
    }

    var supportsVideoBitRate: Bool {
        switch self {
        case .auto, .proresCPU:
            return false
        default:
            return true
        }
    }

    func isCompatible(with format: VideoFormatOption) -> Bool {
        if !format.supportsVideoEncoderSelection {
            return self == .auto
        }

        let muxers = Set(format.ffmpegRequiredMuxers)

        switch self {
        case .auto:
            return format.allowsFFmpegAutomaticVideoCodec || format.avFileType != nil
        case .h264CPU, .h264GPU:
            return muxers.isEmpty || muxers.isDisjoint(with: ["webm", "ogg"])
        case .h265CPU, .h265GPU:
            return muxers.isEmpty || muxers.isDisjoint(with: ["webm", "ogg", "flv"])
        case .mpeg4CPU:
            return muxers.isEmpty || muxers.isDisjoint(with: ["webm", "ogg"])
        case .vp9CPU, .vp8CPU:
            return muxers.isEmpty || muxers.contains("webm") || muxers.contains("matroska")
        case .av1CPU:
            return muxers.isEmpty ||
                muxers.contains("webm") ||
                muxers.contains("matroska") ||
                muxers.contains("mp4") ||
                muxers.contains("mov")
        case .mpeg2CPU:
            return muxers.isEmpty || muxers.contains("mpegts") || muxers.contains("mpeg")
        case .proresCPU:
            return muxers.isEmpty || muxers.contains("mov") || muxers.contains("matroska")
        }
    }
}

enum ResolutionOption: String, CaseIterable, Identifiable {
    case original = "Original"
    case r3840x2160 = "3840x2160"
    case r2560x1440 = "2560x1440"
    case r1920x1080 = "1920x1080"
    case r1280x720 = "1280x720"
    case r640x480 = "640x480"
    case r480x360 = "480x360"
    case r320x240 = "320x240"
    case r192x144 = "192x144"

    var id: String { rawValue }

    var dimensions: (width: Int, height: Int)? {
        switch self {
        case .original:
            return nil
        case .r3840x2160:
            return (3840, 2160)
        case .r2560x1440:
            return (2560, 1440)
        case .r1920x1080:
            return (1920, 1080)
        case .r1280x720:
            return (1280, 720)
        case .r640x480:
            return (640, 480)
        case .r480x360:
            return (480, 360)
        case .r320x240:
            return (320, 240)
        case .r192x144:
            return (192, 144)
        }
    }
}

enum FrameRateOption: String, CaseIterable, Identifiable {
    case original = "Original"
    case fps120 = "120 FPS"
    case fps90 = "90 FPS"
    case fps60 = "60 FPS"
    case fps50 = "50 FPS"
    case fps40 = "40 FPS"
    case fps30 = "30 FPS"
    case fps25 = "25 FPS"
    case fps24 = "24 FPS"
    case fps20 = "20 FPS"
    case fps15 = "15 FPS"
    case fps12 = "12 FPS"
    case fps10 = "10 FPS"
    case fps5 = "5 FPS"
    case fps1 = "1 FPS"

    var id: String { rawValue }

    var fps: Int? {
        switch self {
        case .original:
            return nil
        case .fps120:
            return 120
        case .fps90:
            return 90
        case .fps60:
            return 60
        case .fps50:
            return 50
        case .fps40:
            return 40
        case .fps30:
            return 30
        case .fps25:
            return 25
        case .fps24:
            return 24
        case .fps20:
            return 20
        case .fps15:
            return 15
        case .fps12:
            return 12
        case .fps10:
            return 10
        case .fps5:
            return 5
        case .fps1:
            return 1
        }
    }
}

enum GIFPlaybackSpeedOption: String, CaseIterable, Identifiable {
    case x0_5 = "0.5x"
    case x0_75 = "0.75x"
    case x1_0 = "1.0x"
    case x1_25 = "1.25x"
    case x1_5 = "1.5x"
    case x1_75 = "1.75x"
    case x2_0 = "2.0x"
    case x3_0 = "3.0x"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .x0_5:
            return 0.5
        case .x0_75:
            return 0.75
        case .x1_0:
            return 1.0
        case .x1_25:
            return 1.25
        case .x1_5:
            return 1.5
        case .x1_75:
            return 1.75
        case .x2_0:
            return 2.0
        case .x3_0:
            return 3.0
        }
    }
}

enum VideoBitRateOption: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case kbps50000 = "50000 Kbps"
    case kbps40000 = "40000 Kbps"
    case kbps30000 = "30000 Kbps"
    case kbps20000 = "20000 Kbps"
    case kbps10000 = "10000 Kbps"
    case kbps9000 = "9000 Kbps"
    case kbps8000 = "8000 Kbps"
    case kbps7000 = "7000 Kbps"
    case kbps6000 = "6000 Kbps"
    case kbps5000 = "5000 Kbps"
    case kbps4000 = "4000 Kbps"
    case kbps3000 = "3000 Kbps"
    case kbps2000 = "2000 Kbps"
    case kbps1000 = "1000 Kbps"
    case kbps500 = "500 Kbps"
    case custom = "Custom"

    var id: String { rawValue }

    var kbps: Int? {
        switch self {
        case .auto, .custom:
            return nil
        case .kbps50000:
            return 50000
        case .kbps40000:
            return 40000
        case .kbps30000:
            return 30000
        case .kbps20000:
            return 20000
        case .kbps10000:
            return 10000
        case .kbps9000:
            return 9000
        case .kbps8000:
            return 8000
        case .kbps7000:
            return 7000
        case .kbps6000:
            return 6000
        case .kbps5000:
            return 5000
        case .kbps4000:
            return 4000
        case .kbps3000:
            return 3000
        case .kbps2000:
            return 2000
        case .kbps1000:
            return 1000
        case .kbps500:
            return 500
        }
    }
}

enum AudioEncoderOption: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case aac = "AAC"
    case opus = "Opus"
    case mp3 = "MP3"
    case ac3 = "AC-3"
    case flac = "FLAC"
    case pcm = "PCM"

    var id: String { rawValue }

    var codecCandidates: [String] {
        switch self {
        case .auto:
            return []
        case .aac:
            return ["aac"]
        case .opus:
            return ["libopus", "opus"]
        case .mp3:
            return ["libmp3lame", "mp3"]
        case .ac3:
            return ["ac3", "eac3"]
        case .flac:
            return ["flac"]
        case .pcm:
            return ["pcm_s24le", "pcm_s16le", "pcm_s32le"]
        }
    }

    var supportsSampleRate: Bool {
        switch self {
        case .auto:
            return false
        default:
            return true
        }
    }

    var supportsAudioBitRate: Bool {
        switch self {
        case .auto, .flac, .pcm:
            return false
        default:
            return true
        }
    }

    func isCompatible(with format: VideoFormatOption) -> Bool {
        if !format.supportsAudioTrack {
            return false
        }

        let muxers = Set(format.ffmpegRequiredMuxers)

        switch self {
        case .auto:
            return format.allowsFFmpegAutomaticAudioCodec || format.avFileType != nil
        case .aac:
            return muxers.isEmpty || muxers.isDisjoint(with: ["webm", "ogg"])
        case .mp3:
            return muxers.isEmpty || muxers.isDisjoint(with: ["webm"])
        case .ac3:
            return muxers.isEmpty || muxers.isDisjoint(with: ["webm", "ogg"])
        case .opus:
            return muxers.isEmpty || muxers.contains("webm") || muxers.contains("matroska") || muxers.contains("ogg")
        case .flac:
            return muxers.isEmpty || muxers.contains("matroska") || muxers.contains("ogg")
        case .pcm:
            return muxers.isEmpty || muxers.contains("mov") || muxers.contains("matroska") || muxers.contains("avi")
        }
    }
}

enum AudioModeOption: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case stereo = "Stereo"
    case mono = "Mono"

    var id: String { rawValue }

    var channelCount: Int? {
        switch self {
        case .auto:
            return nil
        case .stereo:
            return 2
        case .mono:
            return 1
        }
    }
}

enum SampleRateOption: String, CaseIterable, Identifiable {
    case hz48000 = "48000 HZ"
    case hz44100 = "44100 HZ"
    case hz32000 = "32000 HZ"
    case hz16000 = "16000 HZ"

    var id: String { rawValue }

    var hertz: Int {
        switch self {
        case .hz48000:
            return 48000
        case .hz44100:
            return 44100
        case .hz32000:
            return 32000
        case .hz16000:
            return 16000
        }
    }
}

enum AudioBitRateOption: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case kbps320 = "320 Kbps"
    case kbps256 = "256 Kbps"
    case kbps192 = "192 Kbps"
    case kbps160 = "160 Kbps"
    case kbps128 = "128 Kbps"
    case kbps96 = "96 Kbps"
    case kbps80 = "80 Kbps"
    case kbps64 = "64 Kbps"

    var id: String { rawValue }

    var kbps: Int? {
        switch self {
        case .auto:
            return nil
        case .kbps320:
            return 320
        case .kbps256:
            return 256
        case .kbps192:
            return 192
        case .kbps160:
            return 160
        case .kbps128:
            return 128
        case .kbps96:
            return 96
        case .kbps80:
            return 80
        case .kbps64:
            return 64
        }
    }
}
