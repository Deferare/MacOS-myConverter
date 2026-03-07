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

    nonisolated var id: String { rawValue }

    nonisolated var codecCandidates: [String] {
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

    nonisolated var usesHEVCCodec: Bool {
        switch self {
        case .h265CPU, .h265GPU:
            return true
        default:
            return false
        }
    }

    nonisolated var supportsVideoBitRate: Bool {
        switch self {
        case .auto, .proresCPU:
            return false
        default:
            return true
        }
    }

    nonisolated func isCompatible(with format: VideoFormatOption) -> Bool {
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
