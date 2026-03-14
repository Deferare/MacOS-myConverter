import Foundation

extension ImageFormatOption {
    nonisolated static func deduplicatedAndSorted(_ formats: [ImageFormatOption]) -> [ImageFormatOption] {
        FormatOptionUtilities.deduplicatedAndSorted(
            formats,
            normalizedID: { $0.normalizedID },
            merge: { $0.merged(with: $1) },
            displayName: { $0.displayName }
        )
    }

    nonisolated func merged(with other: ImageFormatOption) -> ImageFormatOption {
        ImageFormatOption(
            id: id,
            displayName: displayName.count >= other.displayName.count ? displayName : other.displayName,
            fileExtension: fileExtension,
            imageIOUTTypeIdentifier: imageIOUTTypeIdentifier ?? other.imageIOUTTypeIdentifier,
            supportsCompressionQuality: supportsCompressionQuality || other.supportsCompressionQuality,
            supportsAnimation: supportsAnimation || other.supportsAnimation,
            supportsPNGCompressionLevel: supportsPNGCompressionLevel || other.supportsPNGCompressionLevel,
            ffmpegEncoderCandidates: FormatOptionUtilities.uniqueNonEmptyStrings(
                ffmpegEncoderCandidates + other.ffmpegEncoderCandidates
            ),
            ffmpegRequiredMuxers: FormatOptionUtilities.uniqueNonEmptyStrings(
                ffmpegRequiredMuxers + other.ffmpegRequiredMuxers
            ),
            preferredFFmpegMuxer: preferredFFmpegMuxer ?? other.preferredFFmpegMuxer,
            allowsFFmpegAutomaticCodec: allowsFFmpegAutomaticCodec || other.allowsFFmpegAutomaticCodec
        )
    }
}
