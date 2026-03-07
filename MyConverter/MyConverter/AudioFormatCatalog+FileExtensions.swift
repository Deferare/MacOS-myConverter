import Foundation

extension AudioFormatCatalog {
    nonisolated static let byFileExtension: [String: AudioFormatProfile] = {
        var map: [String: AudioFormatProfile] = [:]
        for profile in byIdentifier.values {
            map[profile.fileExtension] = profile
        }

        if let m4a = map["m4a"] {
            map["m4b"] = map["m4b"] ?? m4a
            map["m4r"] = map["m4r"] ?? m4a
        }
        if let ogg = map["ogg"] {
            map["oga"] = map["oga"] ?? ogg
        }
        if let aiff = map["aiff"] {
            map["aif"] = map["aif"] ?? aiff
        }
        if let aac = map["aac"] {
            map["adts"] = map["adts"] ?? aac
        }

        return map
    }()
}
