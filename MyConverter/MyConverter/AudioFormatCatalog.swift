import Foundation

struct AudioFormatProfile {
    let id: String
    let displayName: String
    let fileExtension: String
    let ffmpegRequiredMuxers: [String]
    let preferredFFmpegMuxer: String?
    let allowsFFmpegAutomaticAudioCodec: Bool

    nonisolated var asOption: AudioFormatOption {
        AudioFormatOption(
            id: id,
            displayName: displayName,
            fileExtension: fileExtension,
            ffmpegRequiredMuxers: ffmpegRequiredMuxers,
            preferredFFmpegMuxer: preferredFFmpegMuxer,
            allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec
        )
    }
}

enum AudioFormatCatalog {
}
