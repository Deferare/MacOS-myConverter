enum ContentViewModelSupport {
    private static let cachedFallbackVideoFormat = VideoFormatOption.fromFFmpegExtension("mp4", muxer: "mp4")
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

    static func fallbackVideoFormat() -> VideoFormatOption {
        cachedFallbackVideoFormat
    }

    static func placeholderVideoFormats() -> [VideoFormatOption] {
        cachedPlaceholderVideoFormats
    }

    static func defaultVideoFormat() -> VideoFormatOption {
        cachedDefaultVideoFormat
    }

    static func placeholderVideoEncoders(for format: VideoFormatOption) -> [VideoEncoderOption] {
        if !format.supportsVideoEncoderSelection {
            return [.auto]
        }

        let options = VideoEncoderOption.allCases.filter { option in
            switch option {
            case .auto, .h264GPU, .h264CPU, .mpeg4CPU:
                return option.isCompatible(with: format)
            default:
                return false
            }
        }

        return options.isEmpty ? [.auto] : options
    }

    static func placeholderVideoAudioEncoders(for format: VideoFormatOption) -> [AudioEncoderOption] {
        guard format.supportsAudioTrack else { return [] }

        let options = AudioEncoderOption.allCases.filter { option in
            switch option {
            case .auto, .aac, .mp3:
                return option.isCompatible(with: format)
            default:
                return false
            }
        }

        return options.isEmpty ? [.auto] : options
    }

    static func placeholderImageFormats() -> [ImageFormatOption] {
        cachedPlaceholderImageFormats
    }

    static func fallbackAudioFormat() -> AudioFormatOption {
        cachedFallbackAudioFormat
    }

    static func placeholderAudioFormats() -> [AudioFormatOption] {
        cachedPlaceholderAudioFormats
    }

    static func defaultAudioFormat() -> AudioFormatOption {
        cachedDefaultAudioFormat
    }

    static func placeholderAudioOutputEncoders(for format: AudioFormatOption) -> [AudioEncoderOption] {
        let options = AudioEncoderOption.allCases.filter { option in
            switch option {
            case .auto, .aac, .mp3:
                return option.isCompatible(with: format)
            default:
                return false
            }
        }

        return options.isEmpty ? [.auto] : options
    }
}
