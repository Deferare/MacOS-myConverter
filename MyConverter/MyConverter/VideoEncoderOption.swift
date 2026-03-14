enum VideoEncoderOption: String, CaseIterable, Identifiable, Sendable {
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
        profile.codecCandidates
    }

    nonisolated var usesHEVCCodec: Bool {
        profile.usesHEVCCodec
    }

    nonisolated var supportsVideoBitRate: Bool {
        profile.supportsVideoBitRate
    }

    nonisolated func isCompatible(with format: VideoFormatOption) -> Bool {
        if !format.supportsVideoEncoderSelection {
            return self == .auto
        }

        return profile.isCompatible(format)
    }
}
