import Foundation

extension AudioFormatCatalog {
    nonisolated static let ffmpegOnlyProfiles: [AudioFormatProfile] = {
        [
            byIdentifier["ffmpeg.m4a"],
            byIdentifier["ffmpeg.mp3"],
            byIdentifier["ffmpeg.wav"],
            byIdentifier["ffmpeg.flac"],
            byIdentifier["ffmpeg.ogg"],
            byIdentifier["ffmpeg.opus"],
            byIdentifier["ffmpeg.aac"],
            byIdentifier["ffmpeg.aiff"],
            byIdentifier["ffmpeg.caf"],
            byIdentifier["ffmpeg.mka"]
        ].compactMap { $0 }
    }()
}
