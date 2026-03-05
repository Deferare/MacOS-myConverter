import Foundation

private enum ContentViewModelSettingsDefaults {
    static var defaultVideoFormatID: String {
        ContentViewModelSupport.defaultVideoFormat().id
    }

    static var defaultAudioFormatID: String {
        ContentViewModelSupport.defaultAudioFormat().id
    }
}

private extension KeyedDecodingContainer {
    func decodeRequiredString(forKey key: Key) throws -> String {
        try decode(String.self, forKey: key)
    }

    func decodeString(forKey key: Key, default defaultValue: String) throws -> String {
        try decodeIfPresent(String.self, forKey: key) ?? defaultValue
    }

    func decodeBool(forKey key: Key, default defaultValue: Bool) throws -> Bool {
        try decodeIfPresent(Bool.self, forKey: key) ?? defaultValue
    }
}

private func restoredOption<Option: RawRepresentable>(
    _ rawValue: String,
    default defaultValue: Option
) -> Option where Option.RawValue == String {
    Option(rawValue: rawValue) ?? defaultValue
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
        outputFormat = try container.decodeRequiredString(forKey: .outputFormat)
        videoEncoder = try container.decodeRequiredString(forKey: .videoEncoder)
        resolution = try container.decodeRequiredString(forKey: .resolution)
        frameRate = try container.decodeRequiredString(forKey: .frameRate)
        gifPlaybackSpeed = try container.decodeString(
            forKey: .gifPlaybackSpeed,
            default: GIFPlaybackSpeedOption.x1_5.rawValue
        )
        videoBitRate = try container.decodeRequiredString(forKey: .videoBitRate)
        customVideoBitRate = try container.decodeRequiredString(forKey: .customVideoBitRate)
        audioEncoder = try container.decodeRequiredString(forKey: .audioEncoder)
        audioMode = try container.decodeRequiredString(forKey: .audioMode)
        sampleRate = try container.decodeRequiredString(forKey: .sampleRate)
        audioBitRate = try container.decodeRequiredString(forKey: .audioBitRate)
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
            videoEncoder: restoredOption(videoEncoder, default: .h264GPU),
            resolution: restoredOption(resolution, default: .original),
            frameRate: restoredOption(frameRate, default: .original),
            gifPlaybackSpeed: restoredOption(gifPlaybackSpeed, default: .x1_5),
            videoBitRate: restoredOption(videoBitRate, default: .auto),
            customVideoBitRate: customVideoBitRate,
            audioEncoder: restoredOption(audioEncoder, default: .aac),
            audioMode: restoredOption(audioMode, default: .auto),
            sampleRate: restoredOption(sampleRate, default: .hz48000),
            audioBitRate: restoredOption(audioBitRate, default: .auto)
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
        outputFormat = try container.decodeRequiredString(forKey: .outputFormat)
        resolution = try container.decodeRequiredString(forKey: .resolution)
        quality = try container.decodeRequiredString(forKey: .quality)
        pngCompressionLevel = try container.decodeString(
            forKey: .pngCompressionLevel,
            default: PNGCompressionLevelOption.balanced.rawValue
        )
        preserveAnimation = try container.decodeBool(forKey: .preserveAnimation, default: true)
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
            resolution: restoredOption(resolution, default: .original),
            quality: restoredOption(quality, default: .high),
            pngCompressionLevel: restoredOption(pngCompressionLevel, default: .balanced),
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
        outputFormat = try container.decodeRequiredString(forKey: .outputFormat)
        audioEncoder = try container.decodeRequiredString(forKey: .audioEncoder)
        audioMode = try container.decodeRequiredString(forKey: .audioMode)
        sampleRate = try container.decodeRequiredString(forKey: .sampleRate)
        audioBitRate = try container.decodeRequiredString(forKey: .audioBitRate)
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
            audioEncoder: restoredOption(audioEncoder, default: .aac),
            audioMode: restoredOption(audioMode, default: .auto),
            sampleRate: restoredOption(sampleRate, default: .hz48000),
            audioBitRate: restoredOption(audioBitRate, default: .auto)
        )
    }
}
