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
