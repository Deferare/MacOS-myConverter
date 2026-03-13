enum AudioEncoderOption: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case aac = "AAC"
    case opus = "Opus"
    case mp3 = "MP3"
    case ac3 = "AC-3"
    case flac = "FLAC"
    case pcm = "PCM"

    nonisolated var id: String { rawValue }

    private struct Profile {
        let codecCandidates: [String]
        let supportsSampleRate: Bool
        let supportsAudioBitRate: Bool
        let isVideoCompatible: (VideoFormatOption) -> Bool
        let isAudioCompatible: (AudioFormatOption) -> Bool
    }

    private static let profiles: [Self: Profile] = [
        .auto: Profile(
            codecCandidates: [],
            supportsSampleRate: false,
            supportsAudioBitRate: false,
            isVideoCompatible: { format in
                format.allowsFFmpegAutomaticAudioCodec || format.avFileType != nil
            },
            isAudioCompatible: { $0.allowsFFmpegAutomaticAudioCodec }
        ),
        .aac: Profile(
            codecCandidates: ["aac"],
            supportsSampleRate: true,
            supportsAudioBitRate: true,
            isVideoCompatible: { format in
                Set(format.ffmpegRequiredMuxers).isEmpty ||
                    Set(format.ffmpegRequiredMuxers).isDisjoint(with: ["webm", "ogg"])
            },
            isAudioCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("adts") ||
                    muxers.contains("ipod") ||
                    muxers.contains("mp4") ||
                    muxers.contains("mov") ||
                    muxers.contains("matroska")
            }
        ),
        .opus: Profile(
            codecCandidates: ["libopus", "opus"],
            supportsSampleRate: true,
            supportsAudioBitRate: true,
            isVideoCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("webm") ||
                    muxers.contains("matroska") ||
                    muxers.contains("ogg")
            },
            isAudioCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("ogg") ||
                    muxers.contains("opus") ||
                    muxers.contains("matroska") ||
                    muxers.contains("webm")
            }
        ),
        .mp3: Profile(
            codecCandidates: ["libmp3lame", "mp3"],
            supportsSampleRate: true,
            supportsAudioBitRate: true,
            isVideoCompatible: { format in
                Set(format.ffmpegRequiredMuxers).isEmpty ||
                    Set(format.ffmpegRequiredMuxers).isDisjoint(with: ["webm"])
            },
            isAudioCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("mp3") ||
                    muxers.contains("matroska")
            }
        ),
        .ac3: Profile(
            codecCandidates: ["ac3", "eac3"],
            supportsSampleRate: true,
            supportsAudioBitRate: true,
            isVideoCompatible: { format in
                Set(format.ffmpegRequiredMuxers).isEmpty ||
                    Set(format.ffmpegRequiredMuxers).isDisjoint(with: ["webm", "ogg"])
            },
            isAudioCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("ac3") ||
                    muxers.contains("eac3") ||
                    muxers.contains("matroska") ||
                    muxers.contains("mpegts")
            }
        ),
        .flac: Profile(
            codecCandidates: ["flac"],
            supportsSampleRate: true,
            supportsAudioBitRate: false,
            isVideoCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("matroska") ||
                    muxers.contains("ogg")
            },
            isAudioCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("flac") ||
                    muxers.contains("ogg") ||
                    muxers.contains("matroska")
            }
        ),
        .pcm: Profile(
            codecCandidates: ["pcm_s24le", "pcm_s16le", "pcm_s32le"],
            supportsSampleRate: true,
            supportsAudioBitRate: false,
            isVideoCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("mov") ||
                    muxers.contains("matroska") ||
                    muxers.contains("avi")
            },
            isAudioCompatible: { format in
                let muxers = Set(format.ffmpegRequiredMuxers)
                return muxers.isEmpty ||
                    muxers.contains("wav") ||
                    muxers.contains("aiff") ||
                    muxers.contains("caf") ||
                    muxers.contains("mov") ||
                    muxers.contains("matroska")
            }
        )
    ]

    private var profile: Profile {
        Self.profiles[self] ?? Self.profiles[.auto]!
    }

    nonisolated var codecCandidates: [String] {
        profile.codecCandidates
    }

    nonisolated var supportsSampleRate: Bool {
        profile.supportsSampleRate
    }

    nonisolated var supportsAudioBitRate: Bool {
        profile.supportsAudioBitRate
    }

    nonisolated func isCompatible(with format: VideoFormatOption) -> Bool {
        if !format.supportsAudioTrack {
            return false
        }

        return profile.isVideoCompatible(format)
    }

    nonisolated func isCompatible(with format: AudioFormatOption) -> Bool {
        profile.isAudioCompatible(format)
    }
}
