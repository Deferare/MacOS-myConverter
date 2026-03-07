import Foundation

extension FFmpegArgumentBuilder {
    static func makeAudioArguments(
        inputURL: URL,
        outputURL: URL,
        settings: AudioOutputSettings,
        audioCodec: String?
    ) -> [String] {
        var args = makeBaseArguments(inputURL: inputURL)
        args.append("-vn")

        appendSharedAudioEncodingArguments(
            &args,
            audioCodec: audioCodec,
            sampleRate: settings.sampleRate,
            channels: settings.audioChannels,
            audioBitRateKbps: settings.audioBitRateKbps
        )

        appendMuxerAndOutputArguments(
            &args,
            preferredMuxer: settings.containerFormat.preferredFFmpegMuxer,
            outputURL: outputURL
        )

        return args
    }
}
