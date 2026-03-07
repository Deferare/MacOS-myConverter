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
        self == .original ? nil : parsedDimensions(in: rawValue)
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
        self == .original ? nil : parsedLeadingInteger(in: rawValue)
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
        parsedTrailingDouble(in: rawValue, trimming: "x") ?? 1.0
    }
}
