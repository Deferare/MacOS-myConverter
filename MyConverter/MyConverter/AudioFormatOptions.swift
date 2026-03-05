import Foundation
import UniformTypeIdentifiers

struct AudioFormatOption: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let fileExtension: String
    let ffmpegRequiredMuxers: [String]
    let preferredFFmpegMuxer: String?
    let allowsFFmpegAutomaticAudioCodec: Bool

    var normalizedID: String {
        id.lowercased()
    }

    static func == (lhs: AudioFormatOption, rhs: AudioFormatOption) -> Bool {
        lhs.normalizedID == rhs.normalizedID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(normalizedID)
    }

    static var ffmpegKnownFormats: [AudioFormatOption] {
        AudioFormatCatalog.ffmpegOnlyProfiles.map { $0.asOption }
    }

    static func fromFFmpegExtension(_ fileExtension: String, muxer: String) -> AudioFormatOption {
        let normalizedExtension = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()
        let profile = AudioFormatCatalog.byFileExtension[normalizedExtension]
        let resolved = FormatOptionUtilities.resolveFFmpegFormatMetadata(
            fileExtension: fileExtension,
            muxer: normalizedMuxer,
            profile: profile,
            profileID: { $0.id },
            profileDisplayName: { $0.displayName },
            profileFileExtension: { $0.fileExtension },
            profileRequiredMuxers: { $0.ffmpegRequiredMuxers },
            profilePreferredMuxer: { $0.preferredFFmpegMuxer }
        )

        return AudioFormatOption(
            id: resolved.id,
            displayName: resolved.displayName,
            fileExtension: resolved.fileExtension,
            ffmpegRequiredMuxers: resolved.requiredMuxers,
            preferredFFmpegMuxer: resolved.preferredMuxer,
            allowsFFmpegAutomaticAudioCodec: profile?.allowsFFmpegAutomaticAudioCodec ?? true
        )
    }

    static func deduplicatedAndSorted(_ formats: [AudioFormatOption]) -> [AudioFormatOption] {
        FormatOptionUtilities.deduplicatedAndSorted(
            formats,
            normalizedID: { $0.normalizedID },
            merge: { $0.merged(with: $1) },
            displayName: { $0.displayName }
        )
    }

    static func defaultSelection(from formats: [AudioFormatOption]) -> AudioFormatOption? {
        let normalized = deduplicatedAndSorted(formats)
        guard !normalized.isEmpty else { return nil }

        return FormatOptionUtilities.firstPreferredOption(
            in: normalized,
            preferredExtensions: ["m4a", "mp3", "wav", "flac"],
            fileExtension: { $0.fileExtension }
        )
    }

    static func isLikelyAudioFileExtension(_ fileExtension: String) -> Bool {
        let normalized = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        guard !normalized.isEmpty else { return false }

        if let utType = UTType(filenameExtension: normalized),
           utType.conforms(to: .audio) {
            return true
        }

        return knownAudioExtensions.contains(normalized)
    }

    private func merged(with other: AudioFormatOption) -> AudioFormatOption {
        AudioFormatOption(
            id: id,
            displayName: FormatOptionUtilities.preferredDisplayName(displayName, other.displayName),
            fileExtension: fileExtension,
            ffmpegRequiredMuxers: FormatOptionUtilities.uniqueLowercasedTrimmedStrings(
                ffmpegRequiredMuxers + other.ffmpegRequiredMuxers
            ),
            preferredFFmpegMuxer: preferredFFmpegMuxer ?? other.preferredFFmpegMuxer,
            allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec || other.allowsFFmpegAutomaticAudioCodec
        )
    }

    private static let knownAudioExtensions: Set<String> = [
        "aac", "ac3", "aif", "aiff", "alac", "caf", "flac", "m4a", "m4b", "mka", "mp2",
        "mp3", "oga", "ogg", "opus", "wav", "wma"
    ]
}
