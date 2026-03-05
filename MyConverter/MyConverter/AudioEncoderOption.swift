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

    func isCompatible(with format: AudioFormatOption) -> Bool {
        let muxers = Set(format.ffmpegRequiredMuxers)

        switch self {
        case .auto:
            return format.allowsFFmpegAutomaticAudioCodec
        case .aac:
            return muxers.isEmpty ||
                muxers.contains("adts") ||
                muxers.contains("ipod") ||
                muxers.contains("mp4") ||
                muxers.contains("mov") ||
                muxers.contains("matroska")
        case .opus:
            return muxers.isEmpty ||
                muxers.contains("ogg") ||
                muxers.contains("opus") ||
                muxers.contains("matroska") ||
                muxers.contains("webm")
        case .mp3:
            return muxers.isEmpty ||
                muxers.contains("mp3") ||
                muxers.contains("matroska")
        case .ac3:
            return muxers.isEmpty ||
                muxers.contains("ac3") ||
                muxers.contains("eac3") ||
                muxers.contains("matroska") ||
                muxers.contains("mpegts")
        case .flac:
            return muxers.isEmpty ||
                muxers.contains("flac") ||
                muxers.contains("ogg") ||
                muxers.contains("matroska")
        case .pcm:
            return muxers.isEmpty ||
                muxers.contains("wav") ||
                muxers.contains("aiff") ||
                muxers.contains("caf") ||
                muxers.contains("mov") ||
                muxers.contains("matroska")
        }
    }
}
