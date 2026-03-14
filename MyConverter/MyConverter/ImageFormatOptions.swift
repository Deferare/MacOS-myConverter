import Foundation
import UniformTypeIdentifiers

struct ImageFormatOption: Identifiable, Hashable, Sendable {
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

    nonisolated var utType: UTType? {
        let identifier = imageIOUTTypeIdentifier ?? id
        return FormatOptionUtilities.cachedUTType(forIdentifier: identifier)
    }

    nonisolated var normalizedID: String {
        id.lowercased()
    }

    nonisolated static func == (lhs: ImageFormatOption, rhs: ImageFormatOption) -> Bool {
        lhs.normalizedID == rhs.normalizedID
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(normalizedID)
    }
}
