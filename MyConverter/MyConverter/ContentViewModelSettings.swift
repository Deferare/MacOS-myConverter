import Foundation

private enum ContentViewModelSettingsDefaults {
    static var defaultVideoFormatID: String {
        if let preferred = VideoFormatOption.defaultSelection(from: VideoConversionEngine.defaultOutputFormats()) {
            return preferred.id
        }
        return VideoFormatOption.fromFFmpegExtension("mp4", muxer: "mp4").id
    }

    static var defaultAudioFormatID: String {
        if let preferred = AudioFormatOption.defaultSelection(from: VideoConversionEngine.defaultAudioOutputFormats()) {
            return preferred.id
        }
        return AudioFormatOption.fromFFmpegExtension("m4a", muxer: "ipod").id
    }
}

struct VideoConversionSettings {
    var outputFormatID: String = ContentViewModelSettingsDefaults.defaultVideoFormatID
    var videoEncoder: VideoEncoderOption = .h264GPU
    var resolution: ResolutionOption = .original
    var frameRate: FrameRateOption = .original
    var gifPlaybackSpeed: GIFPlaybackSpeedOption = .x1_5
    var videoBitRate: VideoBitRateOption = .auto
    var customVideoBitRate: String = "5000"
    var audioEncoder: AudioEncoderOption = .aac
    var audioMode: AudioModeOption = .auto
    var sampleRate: SampleRateOption = .hz48000
    var audioBitRate: AudioBitRateOption = .auto
}

struct PersistedVideoConversionSettings: Codable {
    var outputFormat: String
    var videoEncoder: String
    var resolution: String
    var frameRate: String
    var gifPlaybackSpeed: String
    var videoBitRate: String
    var customVideoBitRate: String
    var audioEncoder: String
    var audioMode: String
    var sampleRate: String
    var audioBitRate: String

    private enum CodingKeys: String, CodingKey {
        case outputFormat
        case videoEncoder
        case resolution
        case frameRate
        case gifPlaybackSpeed
        case videoBitRate
        case customVideoBitRate
        case audioEncoder
        case audioMode
        case sampleRate
        case audioBitRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputFormat = try container.decode(String.self, forKey: .outputFormat)
        videoEncoder = try container.decode(String.self, forKey: .videoEncoder)
        resolution = try container.decode(String.self, forKey: .resolution)
        frameRate = try container.decode(String.self, forKey: .frameRate)
        gifPlaybackSpeed = try container.decodeIfPresent(String.self, forKey: .gifPlaybackSpeed) ?? GIFPlaybackSpeedOption.x1_5.rawValue
        videoBitRate = try container.decode(String.self, forKey: .videoBitRate)
        customVideoBitRate = try container.decode(String.self, forKey: .customVideoBitRate)
        audioEncoder = try container.decode(String.self, forKey: .audioEncoder)
        audioMode = try container.decode(String.self, forKey: .audioMode)
        sampleRate = try container.decode(String.self, forKey: .sampleRate)
        audioBitRate = try container.decode(String.self, forKey: .audioBitRate)
    }

    init(from settings: VideoConversionSettings) {
        outputFormat = settings.outputFormatID
        videoEncoder = settings.videoEncoder.rawValue
        resolution = settings.resolution.rawValue
        frameRate = settings.frameRate.rawValue
        gifPlaybackSpeed = settings.gifPlaybackSpeed.rawValue
        videoBitRate = settings.videoBitRate.rawValue
        customVideoBitRate = settings.customVideoBitRate
        audioEncoder = settings.audioEncoder.rawValue
        audioMode = settings.audioMode.rawValue
        sampleRate = settings.sampleRate.rawValue
        audioBitRate = settings.audioBitRate.rawValue
    }

    var restoredSettings: VideoConversionSettings {
        VideoConversionSettings(
            outputFormatID: outputFormat,
            videoEncoder: VideoEncoderOption(rawValue: videoEncoder) ?? .h264GPU,
            resolution: ResolutionOption(rawValue: resolution) ?? .original,
            frameRate: FrameRateOption(rawValue: frameRate) ?? .original,
            gifPlaybackSpeed: GIFPlaybackSpeedOption(rawValue: gifPlaybackSpeed) ?? .x1_5,
            videoBitRate: VideoBitRateOption(rawValue: videoBitRate) ?? .auto,
            customVideoBitRate: customVideoBitRate,
            audioEncoder: AudioEncoderOption(rawValue: audioEncoder) ?? .aac,
            audioMode: AudioModeOption(rawValue: audioMode) ?? .auto,
            sampleRate: SampleRateOption(rawValue: sampleRate) ?? .hz48000,
            audioBitRate: AudioBitRateOption(rawValue: audioBitRate) ?? .auto
        )
    }
}

struct ImageConversionSettings {
    var outputFormatID: String = "public.png"
    var resolution: ResolutionOption = .original
    var quality: ImageQualityOption = .high
    var pngCompressionLevel: PNGCompressionLevelOption = .balanced
    var preserveAnimation: Bool = true
}

struct PersistedImageConversionSettings: Codable {
    var outputFormat: String
    var resolution: String
    var quality: String
    var pngCompressionLevel: String
    var preserveAnimation: Bool

    private enum CodingKeys: String, CodingKey {
        case outputFormat
        case resolution
        case quality
        case pngCompressionLevel
        case preserveAnimation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputFormat = try container.decode(String.self, forKey: .outputFormat)
        resolution = try container.decode(String.self, forKey: .resolution)
        quality = try container.decode(String.self, forKey: .quality)
        pngCompressionLevel = try container.decodeIfPresent(String.self, forKey: .pngCompressionLevel) ?? PNGCompressionLevelOption.balanced.rawValue
        preserveAnimation = try container.decodeIfPresent(Bool.self, forKey: .preserveAnimation) ?? true
    }

    init(from settings: ImageConversionSettings) {
        outputFormat = settings.outputFormatID
        resolution = settings.resolution.rawValue
        quality = settings.quality.rawValue
        pngCompressionLevel = settings.pngCompressionLevel.rawValue
        preserveAnimation = settings.preserveAnimation
    }

    var restoredSettings: ImageConversionSettings {
        ImageConversionSettings(
            outputFormatID: outputFormat,
            resolution: ResolutionOption(rawValue: resolution) ?? .original,
            quality: ImageQualityOption(rawValue: quality) ?? .high,
            pngCompressionLevel: PNGCompressionLevelOption(rawValue: pngCompressionLevel) ?? .balanced,
            preserveAnimation: preserveAnimation
        )
    }
}

struct AudioConversionSettings {
    var outputFormatID: String = ContentViewModelSettingsDefaults.defaultAudioFormatID
    var audioEncoder: AudioEncoderOption = .aac
    var audioMode: AudioModeOption = .auto
    var sampleRate: SampleRateOption = .hz48000
    var audioBitRate: AudioBitRateOption = .auto
}

struct PersistedAudioConversionSettings: Codable {
    var outputFormat: String
    var audioEncoder: String
    var audioMode: String
    var sampleRate: String
    var audioBitRate: String

    private enum CodingKeys: String, CodingKey {
        case outputFormat
        case audioEncoder
        case audioMode
        case sampleRate
        case audioBitRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputFormat = try container.decode(String.self, forKey: .outputFormat)
        audioEncoder = try container.decode(String.self, forKey: .audioEncoder)
        audioMode = try container.decode(String.self, forKey: .audioMode)
        sampleRate = try container.decode(String.self, forKey: .sampleRate)
        audioBitRate = try container.decode(String.self, forKey: .audioBitRate)
    }

    init(from settings: AudioConversionSettings) {
        outputFormat = settings.outputFormatID
        audioEncoder = settings.audioEncoder.rawValue
        audioMode = settings.audioMode.rawValue
        sampleRate = settings.sampleRate.rawValue
        audioBitRate = settings.audioBitRate.rawValue
    }

    var restoredSettings: AudioConversionSettings {
        AudioConversionSettings(
            outputFormatID: outputFormat,
            audioEncoder: AudioEncoderOption(rawValue: audioEncoder) ?? .aac,
            audioMode: AudioModeOption(rawValue: audioMode) ?? .auto,
            sampleRate: SampleRateOption(rawValue: sampleRate) ?? .hz48000,
            audioBitRate: AudioBitRateOption(rawValue: audioBitRate) ?? .auto
        )
    }
}
