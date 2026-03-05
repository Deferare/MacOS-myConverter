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
