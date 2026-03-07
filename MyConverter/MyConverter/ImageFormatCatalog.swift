import Foundation
import ImageIO

struct ImageFormatProfile {
    let id: String
    let displayName: String
    let fileExtension: String
    let imageIOUTTypeIdentifier: String?
    let supportsCompressionQuality: Bool
    let supportsAnimation: Bool
    let supportsPNGCompressionLevel: Bool
    let ffmpegEncoderCandidates: [String]
    let ffmpegRequiredMuxers: [String]
    let preferredFFmpegMuxer: String?
    let allowsFFmpegAutomaticCodec: Bool
}

enum ImageFormatCatalog {
}
