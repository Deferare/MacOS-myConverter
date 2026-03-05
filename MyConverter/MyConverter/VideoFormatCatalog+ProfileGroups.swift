import AVFoundation

extension VideoFormatCatalog {
    static let avFoundationProfiles: [VideoFormatProfile] = {
        [
            byIdentifier[AVFileType.mp4.rawValue.lowercased()],
            byIdentifier[AVFileType.mov.rawValue.lowercased()],
            byIdentifier[AVFileType.m4v.rawValue.lowercased()]
        ].compactMap { $0 }
    }()

    static let ffmpegOnlyProfiles: [VideoFormatProfile] = {
        [
            byIdentifier["ffmpeg.mkv"],
            byIdentifier["ffmpeg.webm"],
            byIdentifier["ffmpeg.avi"],
            byIdentifier["ffmpeg.flv"],
            byIdentifier["ffmpeg.3gp"],
            byIdentifier["ffmpeg.ts"],
            byIdentifier["ffmpeg.ogv"],
            byIdentifier["ffmpeg.gif"]
        ].compactMap { $0 }
    }()
}
