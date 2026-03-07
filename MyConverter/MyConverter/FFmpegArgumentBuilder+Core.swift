import Foundation

extension FFmpegArgumentBuilder {
    static func appendSharedAudioEncodingArguments(
        _ args: inout [String],
        audioCodec: String?,
        sampleRate: Int?,
        channels: Int?,
        audioBitRateKbps: Int?
    ) {
        if let audioCodec {
            args.append(contentsOf: ["-c:a", audioCodec])
        }

        if let sampleRate {
            args.append(contentsOf: ["-ar", "\(sampleRate)"])
        }

        if let channels {
            args.append(contentsOf: ["-ac", "\(channels)"])
        }

        if let audioBitRateKbps {
            args.append(contentsOf: ["-b:a", "\(audioBitRateKbps)k"])
        }
    }

    static func makeBaseArguments(inputURL: URL) -> [String] {
        [
            "-y",
            "-progress", "pipe:1",
            "-nostats",
            "-i", inputURL.path
        ]
    }

    static func appendMuxerAndOutputArguments(
        _ args: inout [String],
        preferredMuxer: String?,
        outputURL: URL
    ) {
        if let preferredMuxer {
            args.append(contentsOf: ["-f", preferredMuxer])
        }
        args.append(outputURL.path)
    }
}
