import Foundation

extension AudioFormatCatalog {
    nonisolated static let byIdentifier: [String: AudioFormatProfile] = {
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
}
