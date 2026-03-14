enum VideoEncoderOptionProfileCatalog {
    struct Profile: Sendable {
        let codecCandidates: [String]
        let usesHEVCCodec: Bool
        let supportsVideoBitRate: Bool
        let isCompatible: @Sendable (VideoFormatOption) -> Bool
    }

    nonisolated static let profiles: [VideoEncoderOption: Profile] = [
        .auto: Profile(
            codecCandidates: [],
            usesHEVCCodec: false,
            supportsVideoBitRate: false,
            isCompatible: { format in
                format.allowsFFmpegAutomaticVideoCodec || format.avFileType != nil
            }
        ),
        .h265CPU: Profile(
            codecCandidates: ["libx265", "hevc", "h265"],
            usesHEVCCodec: true,
            supportsVideoBitRate: true,
            isCompatible: { format in
                Set(format.ffmpegRequiredMuxers).isEmpty ||
                    Set(format.ffmpegRequiredMuxers).isDisjoint(with: ["webm", "ogg", "flv"])
            }
        ),
        .h265GPU: Profile(
            codecCandidates: ["hevc_videotoolbox", "hevc", "libx265", "h265"],
            usesHEVCCodec: true,
            supportsVideoBitRate: true,
            isCompatible: { format in
                Set(format.ffmpegRequiredMuxers).isEmpty ||
                    Set(format.ffmpegRequiredMuxers).isDisjoint(with: ["webm", "ogg", "flv"])
            }
        ),
        .h264CPU: Profile(
            codecCandidates: ["libx264", "h264", "mpeg4"],
            usesHEVCCodec: false,
            supportsVideoBitRate: true,
            isCompatible: { format in
                Set(format.ffmpegRequiredMuxers).isEmpty ||
                    Set(format.ffmpegRequiredMuxers).isDisjoint(with: ["webm", "ogg"])
            }
        ),
        .h264GPU: Profile(
            codecCandidates: ["h264_videotoolbox", "h264", "libx264", "mpeg4"],
            usesHEVCCodec: false,
            supportsVideoBitRate: true,
            isCompatible: { format in
                Set(format.ffmpegRequiredMuxers).isEmpty ||
                    Set(format.ffmpegRequiredMuxers).isDisjoint(with: ["webm", "ogg"])
            }
        ),
        .av1CPU: Profile(
            codecCandidates: ["libsvtav1", "libaom-av1", "rav1e", "av1"],
            usesHEVCCodec: false,
            supportsVideoBitRate: true,
            isCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("webm") ||
                    muxers.contains("matroska") ||
                    muxers.contains("mp4") ||
                    muxers.contains("mov")
            }
        ),
        .vp9CPU: Profile(
            codecCandidates: ["libvpx-vp9", "vp9"],
            usesHEVCCodec: false,
            supportsVideoBitRate: true,
            isCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("webm") ||
                    muxers.contains("matroska")
            }
        ),
        .vp8CPU: Profile(
            codecCandidates: ["libvpx", "vp8"],
            usesHEVCCodec: false,
            supportsVideoBitRate: true,
            isCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("webm") ||
                    muxers.contains("matroska")
            }
        ),
        .mpeg4CPU: Profile(
            codecCandidates: ["mpeg4"],
            usesHEVCCodec: false,
            supportsVideoBitRate: true,
            isCompatible: { format in
                Set(format.ffmpegRequiredMuxers).isEmpty ||
                    Set(format.ffmpegRequiredMuxers).isDisjoint(with: ["webm", "ogg"])
            }
        ),
        .mpeg2CPU: Profile(
            codecCandidates: ["mpeg2video"],
            usesHEVCCodec: false,
            supportsVideoBitRate: true,
            isCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("mpegts") ||
                    muxers.contains("mpeg")
            }
        ),
        .proresCPU: Profile(
            codecCandidates: ["prores_ks", "prores_aw", "prores"],
            usesHEVCCodec: false,
            supportsVideoBitRate: false,
            isCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("mov") ||
                    muxers.contains("matroska")
            }
        )
    ]
}

extension VideoEncoderOption {
    nonisolated var profile: VideoEncoderOptionProfileCatalog.Profile {
        VideoEncoderOptionProfileCatalog.profiles[self] ?? VideoEncoderOptionProfileCatalog.profiles[.auto]!
    }
}
