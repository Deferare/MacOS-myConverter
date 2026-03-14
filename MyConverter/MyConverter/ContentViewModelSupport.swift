enum ContentViewModelSupport {
    private static let cachedFallbackVideoFormat = VideoFormatOption.fromFFmpegExtension("mp4", muxer: "mp4")
    private static let placeholderVideoEncoderCandidates: [VideoEncoderOption] = [.auto, .h264GPU, .h264CPU, .mpeg4CPU]
    private static let placeholderAudioEncoderCandidates: [AudioEncoderOption] = [.auto, .aac, .mp3]
    private static let cachedPlaceholderVideoFormats: [VideoFormatOption] = {
        let formats = VideoFormatOption.deduplicatedAndSorted(VideoFormatOption.avFoundationDefaultFormats)
        return formats.isEmpty ? [cachedFallbackVideoFormat] : formats
    }()
    private static let cachedDefaultVideoFormat: VideoFormatOption = {
        VideoFormatOption.defaultSelection(from: cachedPlaceholderVideoFormats) ?? cachedFallbackVideoFormat
    }()
    private static let cachedPlaceholderImageFormats = ImageFormatOption.deduplicatedAndSorted([
        ImageFormatOption.fromImageIOTypeIdentifier("public.png"),
        ImageFormatOption.fromImageIOTypeIdentifier("public.jpeg"),
        ImageFormatOption.fromImageIOTypeIdentifier("public.tiff")
    ])
    private static let cachedFallbackAudioFormat = AudioFormatOption.fromFFmpegExtension("m4a", muxer: "ipod")
    private static let cachedPlaceholderAudioFormats: [AudioFormatOption] = {
        let formats = AudioFormatOption.deduplicatedAndSorted(AudioFormatOption.ffmpegKnownFormats)
        return formats.isEmpty ? [cachedFallbackAudioFormat] : formats
    }()
    private static let cachedDefaultAudioFormat: AudioFormatOption = {
        AudioFormatOption.defaultSelection(from: cachedPlaceholderAudioFormats) ?? cachedFallbackAudioFormat
    }()

    static func placeholderVideoFormats() -> [VideoFormatOption] {
        cachedPlaceholderVideoFormats
    }

    static func defaultVideoFormat() -> VideoFormatOption {
        cachedDefaultVideoFormat
    }

    private static func placeholderEncoderOptions<Option: Equatable>(
        candidates: [Option],
        automaticOption: Option,
        isCompatible: (Option) -> Bool
    ) -> [Option] {
        let options = candidates.filter(isCompatible)
        return options.isEmpty ? [automaticOption] : options
    }

    static func placeholderVideoEncoders(for format: VideoFormatOption) -> [VideoEncoderOption] {
        if !format.supportsVideoEncoderSelection {
            return [.auto]
        }

        return placeholderEncoderOptions(
            candidates: placeholderVideoEncoderCandidates,
            automaticOption: .auto,
            isCompatible: { $0.isCompatible(with: format) }
        )
    }

    static func placeholderVideoAudioEncoders(for format: VideoFormatOption) -> [AudioEncoderOption] {
        guard format.supportsAudioTrack else { return [] }

        return placeholderEncoderOptions(
            candidates: placeholderAudioEncoderCandidates,
            automaticOption: .auto,
            isCompatible: { $0.isCompatible(with: format) }
        )
    }

    static func placeholderImageFormats() -> [ImageFormatOption] {
        cachedPlaceholderImageFormats
    }

    static func placeholderAudioFormats() -> [AudioFormatOption] {
        cachedPlaceholderAudioFormats
    }

    static func defaultAudioFormat() -> AudioFormatOption {
        cachedDefaultAudioFormat
    }

    static func placeholderAudioOutputEncoders(for format: AudioFormatOption) -> [AudioEncoderOption] {
        placeholderEncoderOptions(
            candidates: placeholderAudioEncoderCandidates,
            automaticOption: .auto,
            isCompatible: { $0.isCompatible(with: format) }
        )
    }
}
