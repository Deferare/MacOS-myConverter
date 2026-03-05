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
