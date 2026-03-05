import AVFoundation
import Foundation

struct VideoFormatProfile {
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
}

enum VideoFormatCatalog {
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
