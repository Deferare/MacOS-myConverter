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
        AudioFormatProfile.ffmpegOnlyProfiles.map { $0.asOption }
    }

    static func fromFFmpegExtension(_ fileExtension: String, muxer: String) -> AudioFormatOption {
        let normalizedExtension = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()
        let profile = AudioFormatProfile.byFileExtension[normalizedExtension]
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

private struct AudioFormatProfile {
    let id: String
    let displayName: String
    let fileExtension: String
    let ffmpegRequiredMuxers: [String]
    let preferredFFmpegMuxer: String?
    let allowsFFmpegAutomaticAudioCodec: Bool

    var asOption: AudioFormatOption {
        AudioFormatOption(
            id: id,
            displayName: displayName,
            fileExtension: fileExtension,
            ffmpegRequiredMuxers: ffmpegRequiredMuxers,
            preferredFFmpegMuxer: preferredFFmpegMuxer,
            allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec
        )
    }

    static let byIdentifier: [String: AudioFormatProfile] = {
        var map: [String: AudioFormatProfile] = [:]

        func add(
            id: String,
            displayName: String,
            fileExtension: String,
            ffmpegRequiredMuxers: [String],
            preferredFFmpegMuxer: String? = nil,
            allowsFFmpegAutomaticAudioCodec: Bool = true
        ) {
            map[id.lowercased()] = AudioFormatProfile(
                id: id.lowercased(),
                displayName: displayName,
                fileExtension: fileExtension.lowercased(),
                ffmpegRequiredMuxers: ffmpegRequiredMuxers.map { $0.lowercased() },
                preferredFFmpegMuxer: preferredFFmpegMuxer?.lowercased(),
                allowsFFmpegAutomaticAudioCodec: allowsFFmpegAutomaticAudioCodec
            )
        }

        add(
            id: "ffmpeg.m4a",
            displayName: "M4A",
            fileExtension: "m4a",
            ffmpegRequiredMuxers: ["ipod", "mp4"],
            preferredFFmpegMuxer: "ipod"
        )
        add(
            id: "ffmpeg.mp3",
            displayName: "MP3",
            fileExtension: "mp3",
            ffmpegRequiredMuxers: ["mp3"],
            preferredFFmpegMuxer: "mp3"
        )
        add(
            id: "ffmpeg.wav",
            displayName: "WAV",
            fileExtension: "wav",
            ffmpegRequiredMuxers: ["wav"],
            preferredFFmpegMuxer: "wav"
        )
        add(
            id: "ffmpeg.flac",
            displayName: "FLAC",
            fileExtension: "flac",
            ffmpegRequiredMuxers: ["flac"],
            preferredFFmpegMuxer: "flac"
        )
        add(
            id: "ffmpeg.ogg",
            displayName: "Ogg Audio",
            fileExtension: "ogg",
            ffmpegRequiredMuxers: ["ogg"],
            preferredFFmpegMuxer: "ogg"
        )
        add(
            id: "ffmpeg.opus",
            displayName: "Opus",
            fileExtension: "opus",
            ffmpegRequiredMuxers: ["opus", "ogg"],
            preferredFFmpegMuxer: "opus"
        )
        add(
            id: "ffmpeg.aac",
            displayName: "AAC",
            fileExtension: "aac",
            ffmpegRequiredMuxers: ["adts"],
            preferredFFmpegMuxer: "adts"
        )
        add(
            id: "ffmpeg.aiff",
            displayName: "AIFF",
            fileExtension: "aiff",
            ffmpegRequiredMuxers: ["aiff"],
            preferredFFmpegMuxer: "aiff"
        )
        add(
            id: "ffmpeg.caf",
            displayName: "CAF",
            fileExtension: "caf",
            ffmpegRequiredMuxers: ["caf"],
            preferredFFmpegMuxer: "caf"
        )
        add(
            id: "ffmpeg.mka",
            displayName: "Matroska Audio",
            fileExtension: "mka",
            ffmpegRequiredMuxers: ["matroska"],
            preferredFFmpegMuxer: "matroska"
        )

        return map
    }()

    static let byFileExtension: [String: AudioFormatProfile] = {
        var map: [String: AudioFormatProfile] = [:]
        for profile in byIdentifier.values {
            map[profile.fileExtension] = profile
        }

        if let m4a = map["m4a"] {
            map["m4b"] = map["m4b"] ?? m4a
            map["m4r"] = map["m4r"] ?? m4a
        }
        if let ogg = map["ogg"] {
            map["oga"] = map["oga"] ?? ogg
        }
        if let aiff = map["aiff"] {
            map["aif"] = map["aif"] ?? aiff
        }
        if let aac = map["aac"] {
            map["adts"] = map["adts"] ?? aac
        }

        return map
    }()

    static let ffmpegOnlyProfiles: [AudioFormatProfile] = {
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
