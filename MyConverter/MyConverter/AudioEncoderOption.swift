enum AudioEncoderOption: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case aac = "AAC"
    case opus = "Opus"
    case mp3 = "MP3"
    case ac3 = "AC-3"
    case flac = "FLAC"
    case pcm = "PCM"

    nonisolated var id: String { rawValue }

    nonisolated var codecCandidates: [String] {
        profile.codecCandidates
    }

    nonisolated var supportsSampleRate: Bool {
        profile.supportsSampleRate
    }

    nonisolated var supportsAudioBitRate: Bool {
        profile.supportsAudioBitRate
    }

    nonisolated func isCompatible(with format: VideoFormatOption) -> Bool {
        if !format.supportsAudioTrack {
            return false
        }

        return profile.isVideoCompatible(format)
    }

    nonisolated func isCompatible(with format: AudioFormatOption) -> Bool {
        profile.isAudioCompatible(format)
    }
}
