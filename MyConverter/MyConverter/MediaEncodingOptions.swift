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
