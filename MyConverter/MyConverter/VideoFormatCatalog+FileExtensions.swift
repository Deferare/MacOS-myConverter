import Foundation

extension VideoFormatCatalog {
    static let byFileExtension: [String: VideoFormatProfile] = {
        var map: [String: VideoFormatProfile] = [:]
        for profile in byIdentifier.values {
            map[profile.fileExtension] = profile
        }

        if let mpegTs = map["ts"] {
            map["m2ts"] = map["m2ts"] ?? mpegTs
            map["mts"] = map["mts"] ?? mpegTs
        }
        if let mkv = map["mkv"] {
            map["mk3d"] = map["mk3d"] ?? mkv
        }
        if let mp4 = map["mp4"] {
            map["m4p"] = map["m4p"] ?? mp4
        }

        return map
    }()
}
