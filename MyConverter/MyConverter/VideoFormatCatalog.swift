import Foundation

struct VideoFormatProfile {
    let id: String
    let displayName: String
    let fileExtension: String
    let avFileTypeIdentifier: String?
    let supportsFastStart: Bool
    let supportsHEVCTag: Bool
    let supportsAudioTrack: Bool
    let supportsVideoEncoderSelection: Bool
    let usesGIFPalettePipeline: Bool
    let ffmpegRequiredMuxers: [String]
    let preferredFFmpegMuxer: String?
    let allowsFFmpegAutomaticVideoCodec: Bool
    let allowsFFmpegAutomaticAudioCodec: Bool

    var asOption: VideoFormatOption {
        VideoFormatOption(
            id: id,
            displayName: displayName,
            fileExtension: fileExtension,
            avFileTypeIdentifier: avFileTypeIdentifier,
            supportsFastStart: supportsFastStart,
            supportsHEVCTag: supportsHEVCTag,
            supportsAudioTrack: supportsAudioTrack,
            supportsVideoEncoderSelection: supportsVideoEncoderSelection,
            usesGIFPalettePipeline: usesGIFPalettePipeline,
            ffmpegRequiredMuxers: ffmpegRequiredMuxers,
            preferredFFmpegMuxer: preferredFFmpegMuxer,
            allowsFFmpegAutomaticVideoCodec: allowsFFmpegAutomaticVideoCodec,
            allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec
        )
    }
}

enum VideoFormatCatalog {
}
