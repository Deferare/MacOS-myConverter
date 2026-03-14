import Foundation

extension ContentViewModelSupport {
    private static func firstPreferredOption<Option: Equatable>(
        in options: [Option],
        preferredOrder: [Option]
    ) -> Option? {
        guard !options.isEmpty else { return nil }
        return preferredOrder.first(where: options.contains) ?? options.first
    }

    private static func preferredAudioOutputEncoderOrder(for format: AudioFormatOption) -> [AudioEncoderOption] {
        switch format.fileExtension.lowercased() {
        case "m4a", "aac":
            return [.aac, .mp3, .auto]
        case "mp3":
            return [.mp3, .aac, .auto]
        case "wav", "aiff", "aif", "caf":
            return [.pcm, .aac, .mp3, .auto]
        case "flac":
            return [.flac, .aac, .mp3, .auto]
        case "opus", "ogg", "oga":
            return [.opus, .aac, .mp3, .auto]
        default:
            return [.aac, .mp3, .auto]
        }
    }

    static func preferredVideoEncoder(from options: [VideoEncoderOption]) -> VideoEncoderOption? {
        firstPreferredOption(in: options, preferredOrder: [.h264GPU, .h264CPU, .auto])
    }

    static func preferredAudioEncoder(from options: [AudioEncoderOption]) -> AudioEncoderOption? {
        firstPreferredOption(in: options, preferredOrder: [.aac, .auto])
    }

    static func preferredAudioOutputEncoder(
        for format: AudioFormatOption,
        from options: [AudioEncoderOption]
    ) -> AudioEncoderOption? {
        firstPreferredOption(
            in: options,
            preferredOrder: preferredAudioOutputEncoderOrder(for: format)
        )
    }
}
