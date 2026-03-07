import Foundation

extension ContentViewModelSupport {
    static func preferredVideoEncoder(from options: [VideoEncoderOption]) -> VideoEncoderOption? {
        guard !options.isEmpty else { return nil }
        if options.contains(.h264GPU) { return .h264GPU }
        if options.contains(.h264CPU) { return .h264CPU }
        if options.contains(.auto) { return .auto }
        return options.first
    }

    static func preferredAudioEncoder(from options: [AudioEncoderOption]) -> AudioEncoderOption? {
        guard !options.isEmpty else { return nil }
        if options.contains(.aac) { return .aac }
        if options.contains(.auto) { return .auto }
        return options.first
    }

    static func preferredAudioOutputEncoder(
        for format: AudioFormatOption,
        from options: [AudioEncoderOption]
    ) -> AudioEncoderOption? {
        guard !options.isEmpty else { return nil }

        switch format.fileExtension.lowercased() {
        case "m4a", "aac":
            if options.contains(.aac) { return .aac }
        case "mp3":
            if options.contains(.mp3) { return .mp3 }
        case "wav", "aiff", "aif", "caf":
            if options.contains(.pcm) { return .pcm }
        case "flac":
            if options.contains(.flac) { return .flac }
        case "opus", "ogg", "oga":
            if options.contains(.opus) { return .opus }
        default:
            break
        }

        if options.contains(.aac) { return .aac }
        if options.contains(.mp3) { return .mp3 }
        if options.contains(.auto) { return .auto }
        return options.first
    }
}
