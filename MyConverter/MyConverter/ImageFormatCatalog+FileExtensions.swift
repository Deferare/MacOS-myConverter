import UniformTypeIdentifiers

extension ImageFormatCatalog {
    nonisolated static let byFileExtension: [String: ImageFormatProfile] = {
        var map: [String: ImageFormatProfile] = [:]

        for profile in byIdentifier.values {
            let key = profile.fileExtension.lowercased()
            if map[key] == nil {
                map[key] = profile
            }

            if let identifier = profile.imageIOUTTypeIdentifier,
               let utType = FormatOptionUtilities.cachedUTType(forIdentifier: identifier),
               let preferred = utType.preferredFilenameExtension?.lowercased(),
               map[preferred] == nil {
                map[preferred] = profile
            }
        }

        map["jpeg"] = map["jpeg"] ?? map["jpg"]
        map["tif"] = map["tif"] ?? map["tiff"]
        map["heif"] = map["heif"] ?? map["heic"]
        map["j2k"] = map["j2k"] ?? map["jp2"]

        return map
    }()
}
