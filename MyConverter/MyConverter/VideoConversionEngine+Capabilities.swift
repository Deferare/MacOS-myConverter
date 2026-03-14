import Foundation

extension VideoConversionEngine {
    nonisolated static func ffmpegIntrospection(using runtime: any FFmpegRuntime) -> FFmpegIntrospection? {
        try? inspectFFmpeg(using: runtime)
    }

    nonisolated static func supportedIntrospection(
        using runtime: any FFmpegRuntime,
        for format: VideoFormatOption
    ) -> FFmpegIntrospection? {
        guard let introspection = ffmpegIntrospection(using: runtime),
              isFFmpegFormatSupported(format, introspection: introspection) else {
            return nil
        }

        return introspection
    }

    nonisolated static func supportedIntrospection(
        using runtime: any FFmpegRuntime,
        for format: AudioFormatOption
    ) -> FFmpegIntrospection? {
        guard let introspection = ffmpegIntrospection(using: runtime),
              isFFmpegAudioFormatSupported(format, introspection: introspection) else {
            return nil
        }

        return introspection
    }

    nonisolated static func automaticOptionIfEnabled<Option>(
        _ option: Option,
        enabled: Bool
    ) -> [Option] {
        enabled ? [option] : []
    }

    nonisolated static func availableEncoderOptions<Option: CaseIterable & Equatable>(
        availableEncoders: Set<String>,
        allowsAutomatic: Bool,
        automaticOption: Option,
        isCompatible: (Option) -> Bool,
        codecCandidates: (Option) -> [String]
    ) -> [Option] {
        let explicitOptions = Array(Option.allCases).filter { option in
            guard option != automaticOption else { return false }
            return isCompatible(option) &&
                codecCandidates(option).contains(where: availableEncoders.contains)
        }

        return resolvedEncoderOptions(
            explicitOptions: explicitOptions,
            allowsAutomatic: allowsAutomatic,
            automaticOption: automaticOption
        )
    }

    nonisolated static func resolvedEncoderOptions<Option: Equatable>(
        explicitOptions: [Option],
        allowsAutomatic: Bool,
        automaticOption: Option
    ) -> [Option] {
        guard allowsAutomatic, !explicitOptions.isEmpty else {
            return explicitOptions
        }
        return [automaticOption] + explicitOptions
    }

    nonisolated static func makeCapabilityCacheKey(path: String, normalizedID: String) -> String {
        "\(path)|\(normalizedID)"
    }
}
