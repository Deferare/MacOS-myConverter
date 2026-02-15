import Foundation

enum VideoEncoderOption: String, CaseIterable, Identifiable {
    case h265CPU = "H.265(CPU)"
    case h265GPU = "H.265(GPU)"
    case h264CPU = "H.264(CPU)"
    case h264GPU = "H.264(GPU)"

    var id: String { rawValue }

    var codecCandidates: [String] {
        switch self {
        case .h265CPU:
            return ["libx265", "hevc", "h264", "mpeg4"]
        case .h265GPU:
            return ["hevc_videotoolbox", "hevc", "h264_videotoolbox", "h264", "mpeg4"]
        case .h264CPU:
            return ["libx264", "h264", "mpeg4"]
        case .h264GPU:
            return ["h264_videotoolbox", "h264", "mpeg4"]
        }
    }

    var isHEVC: Bool {
        switch self {
        case .h265CPU, .h265GPU:
            return true
        case .h264CPU, .h264GPU:
            return false
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
    case aac = "AAC"

    var id: String { rawValue }

    var codecName: String { "aac" }
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
