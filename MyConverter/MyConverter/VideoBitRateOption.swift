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
