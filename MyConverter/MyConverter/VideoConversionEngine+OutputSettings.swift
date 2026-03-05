import Foundation

struct VideoOutputSettings {
    let containerFormat: VideoFormatOption
    let videoCodecCandidates: [String]
    let useHEVCTag: Bool
    let resolution: (width: Int, height: Int)?
    let frameRate: Int?
    let gifPlaybackSpeed: Double?
    let videoBitRateKbps: Int?
    let audioCodecCandidates: [String]
    let audioChannels: Int?
    let sampleRate: Int?
    let audioBitRateKbps: Int?
}

struct VideoSourceCapabilities {
    let availableOutputFormats: [VideoFormatOption]
    let warningMessage: String?
    let errorMessage: String?
}

struct AudioOutputSettings {
    let containerFormat: AudioFormatOption
    let audioCodecCandidates: [String]
    let audioChannels: Int?
    let sampleRate: Int?
    let audioBitRateKbps: Int?
}

struct AudioSourceCapabilities {
    let availableOutputFormats: [AudioFormatOption]
    let warningMessage: String?
    let errorMessage: String?
}
