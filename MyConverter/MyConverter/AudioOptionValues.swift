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
        Int(rawValue.split(separator: " ").first ?? "") ?? 0
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
        self == .auto ? nil : Int(rawValue.split(separator: " ").first ?? "")
    }
}
