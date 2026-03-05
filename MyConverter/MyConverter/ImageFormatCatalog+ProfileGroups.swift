extension ImageFormatCatalog {
    nonisolated static let ffmpegOnlyProfiles: [ImageFormatProfile] = {
        [
            byIdentifier["org.webmproject.webp"],
            byIdentifier["public.avif"],
            byIdentifier["public.heic"]
        ].compactMap { $0 }
    }()
}
