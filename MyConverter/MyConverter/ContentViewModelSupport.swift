enum ContentViewModelSupport {
    static func fallbackVideoFormat() -> VideoFormatOption {
        VideoFormatOption.fromFFmpegExtension("mp4", muxer: "mp4")
    }

    static func placeholderVideoFormats() -> [VideoFormatOption] {
        let formats = VideoFormatOption.deduplicatedAndSorted(VideoFormatOption.avFoundationDefaultFormats)
        return formats.isEmpty ? [fallbackVideoFormat()] : formats
    }

    static func defaultVideoFormat() -> VideoFormatOption {
        if let preferred = VideoFormatOption.defaultSelection(from: placeholderVideoFormats()) {
            return preferred
        }
        return fallbackVideoFormat()
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
        ImageFormatOption.deduplicatedAndSorted([
            ImageFormatOption.fromImageIOTypeIdentifier("public.png"),
            ImageFormatOption.fromImageIOTypeIdentifier("public.jpeg"),
            ImageFormatOption.fromImageIOTypeIdentifier("public.tiff")
        ])
    }

    static func fallbackAudioFormat() -> AudioFormatOption {
        AudioFormatOption.fromFFmpegExtension("m4a", muxer: "ipod")
    }

    static func placeholderAudioFormats() -> [AudioFormatOption] {
        let formats = AudioFormatOption.deduplicatedAndSorted(AudioFormatOption.ffmpegKnownFormats)
        return formats.isEmpty ? [fallbackAudioFormat()] : formats
    }

    static func defaultAudioFormat() -> AudioFormatOption {
        if let preferred = AudioFormatOption.defaultSelection(from: placeholderAudioFormats()) {
            return preferred
        }
        return fallbackAudioFormat()
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
