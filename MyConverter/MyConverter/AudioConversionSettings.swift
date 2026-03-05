import Foundation

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
