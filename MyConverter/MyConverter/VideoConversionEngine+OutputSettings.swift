import Foundation

struct VideoOutputSettings: Sendable {
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

struct VideoSourceCapabilities: Sendable {
    let availableOutputFormats: [VideoFormatOption]
    let warningMessage: String?
    let errorMessage: String?
}

struct AudioOutputSettings: Sendable {
    let containerFormat: AudioFormatOption
    let audioCodecCandidates: [String]
    let audioChannels: Int?
    let sampleRate: Int?
    let audioBitRateKbps: Int?
}

struct AudioSourceCapabilities: Sendable {
    let availableOutputFormats: [AudioFormatOption]
    let warningMessage: String?
    let errorMessage: String?
}
