import Foundation

enum FFmpegArgumentBuilder {
    static func makeVideoArguments(
        inputURL: URL,
        outputURL: URL,
        settings: VideoOutputSettings,
        videoCodec: String?,
        audioCodec: String?
    ) -> [String] {
        if settings.containerFormat.usesGIFPalettePipeline {
            return makeGIFArguments(
                inputURL: inputURL,
                outputURL: outputURL,
                settings: settings
            )
        }

        var args = makeBaseArguments(inputURL: inputURL)

        if let videoCodec {
            args.append(contentsOf: ["-c:v", videoCodec])
        }

        appendVideoEncodingArguments(&args, settings: settings)
        appendVideoAudioEncodingArguments(&args, settings: settings, audioCodec: audioCodec)

        args.append(contentsOf: ["-pix_fmt", "yuv420p"])
        if settings.containerFormat.supportsFastStart {
            args.append(contentsOf: ["-movflags", "+faststart"])
        }
        appendMuxerAndOutputArguments(
            &args,
            preferredMuxer: settings.containerFormat.preferredFFmpegMuxer,
            outputURL: outputURL
        )

        return args
    }

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

    private static func appendVideoEncodingArguments(
        _ args: inout [String],
        settings: VideoOutputSettings
    ) {
        if let dimensions = settings.resolution {
            args.append(contentsOf: ["-vf", "scale=\(dimensions.width):\(dimensions.height)"])
        }

        if let fps = settings.frameRate {
            args.append(contentsOf: ["-r", "\(fps)"])
        }

        if let videoBitRate = settings.videoBitRateKbps {
            args.append(contentsOf: ["-b:v", "\(videoBitRate)k"])
        }

        if settings.useHEVCTag && settings.containerFormat.supportsHEVCTag {
            args.append(contentsOf: ["-tag:v", "hvc1"])
        }
    }

    private static func appendVideoAudioEncodingArguments(
        _ args: inout [String],
        settings: VideoOutputSettings,
        audioCodec: String?
    ) {
        if !settings.containerFormat.supportsAudioTrack {
            args.append("-an")
            return
        }

        appendSharedAudioEncodingArguments(
            &args,
            audioCodec: audioCodec,
            sampleRate: settings.sampleRate,
            channels: settings.audioChannels,
            audioBitRateKbps: settings.audioBitRateKbps
        )
    }

    private static func appendSharedAudioEncodingArguments(
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

    private static func makeGIFArguments(
        inputURL: URL,
        outputURL: URL,
        settings: VideoOutputSettings
    ) -> [String] {
        var filterParts: [String] = []
        if let speed = settings.gifPlaybackSpeed,
           speed.isFinite,
           speed > 0,
           abs(speed - 1.0) > 0.0001 {
            filterParts.append("setpts=PTS/\(speed)")
        }
        if let fps = settings.frameRate {
            filterParts.append("fps=\(max(1, fps))")
        }
        if let dimensions = settings.resolution {
            filterParts.append("scale=\(dimensions.width):\(dimensions.height):force_original_aspect_ratio=decrease:flags=lanczos")
        }

        let baseFilter = filterParts.isEmpty ? "null" : filterParts.joined(separator: ",")
        let complexFilter = "[0:v]\(baseFilter),split[v0][v1];[v0]palettegen=stats_mode=diff[p];[v1][p]paletteuse=dither=sierra2_4a"

        var args = makeBaseArguments(inputURL: inputURL)
        args.append(contentsOf: [
            "-an",
            "-filter_complex", complexFilter,
            "-loop", "0"
        ])
        appendMuxerAndOutputArguments(&args, preferredMuxer: "gif", outputURL: outputURL)
        return args
    }

    private static func makeBaseArguments(inputURL: URL) -> [String] {
        [
            "-y",
            "-progress", "pipe:1",
            "-nostats",
            "-i", inputURL.path
        ]
    }

    private static func appendMuxerAndOutputArguments(
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
