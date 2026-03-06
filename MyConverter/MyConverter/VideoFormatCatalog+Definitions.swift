import AVFoundation

extension VideoFormatCatalog {
    nonisolated static let byIdentifier: [String: VideoFormatProfile] = {
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
}
